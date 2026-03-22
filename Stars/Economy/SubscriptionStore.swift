//
//  SubscriptionStore.swift
//  Stars
//
//  Manages StoreKit 2 auto-renewable subscriptions.
//  Tier hierarchy: Free < Plus < Pro < Max.
//  Higher tiers include all lower-tier benefits.
//
//  Subscription expiration:
//    - All official-provider agents pause (no token consumption)
//    - Excess self-added agents beyond free limit (20+QTC) pause
//    - Until re-subscription
//

import Foundation
import StoreKit

// MARK: - Subscription Tier

enum SubscriptionTier: Int, Comparable, Codable, Sendable {
    case free = 0
    case plus = 1
    case pro  = 2
    case max  = 3

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .plus: return "Plus"
        case .pro:  return "Pro"
        case .max:  return "Max"
        }
    }

    var productID: String? {
        switch self {
        case .free: return nil
        case .plus: return "com.qingteng.Star.Plus.monthly"
        case .pro:  return "com.qingteng.Star.Pro.monthly"
        case .max:  return "com.qingteng.Star.Max.monthly"
        }
    }

    static let allProductIDs: Set<String> = [
        "com.qingteng.Star.Plus.monthly",
        "com.qingteng.Star.Pro.monthly",
        "com.qingteng.Star.Max.monthly",
    ]

    /// All paid tiers in ascending order.
    static let paidTiers: [SubscriptionTier] = [.plus, .pro, .max]
}

// MARK: - Subscription Store

@MainActor
final class SubscriptionStore {

    static let shared = SubscriptionStore()

    /// Posted when the subscription tier changes.
    static let tierDidChange = Notification.Name("stars.subscription.tierDidChange")

    // MARK: - State

    private let tierKey = "stars.subscription.tier"

    private(set) var currentTier: SubscriptionTier = .free {
        didSet {
            guard oldValue != currentTier else { return }
            UserDefaults.standard.set(currentTier.rawValue, forKey: tierKey)
            NotificationCenter.default.post(name: Self.tierDidChange, object: nil)
        }
    }

    /// StoreKit products for the 3 subscription tiers.
    private(set) var products: [Product] = []

    private var updateListenerTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        // Load cached tier for fast startup
        let cached = UserDefaults.standard.integer(forKey: tierKey)
        currentTier = SubscriptionTier(rawValue: cached) ?? .free

        // Start listening for real-time transaction updates
        updateListenerTask = listenForTransactionUpdates()

        // Verify actual subscription status with StoreKit
        Task {
            await refreshSubscriptionStatus()
            await loadProducts()
        }
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            products = try await Product.products(for: SubscriptionTier.allProductIDs)
            products.sort { a, b in
                tierForProductID(a.id).rawValue < tierForProductID(b.id).rawValue
            }
        } catch {
            print("[SubscriptionStore] Failed to load products: \(error)")
        }
    }

    func product(for tier: SubscriptionTier) -> Product? {
        guard let id = tier.productID else { return nil }
        return products.first { $0.id == id }
    }

    // MARK: - Purchase

    /// Purchase a subscription product. Returns true if successful.
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshSubscriptionStatus()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshSubscriptionStatus()
    }

    // MARK: - Subscription Status

    func refreshSubscriptionStatus() async {
        var highestTier: SubscriptionTier = .free

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // Skip revoked transactions
            if transaction.revocationDate != nil { continue }
            // Skip expired subscriptions
            if let expDate = transaction.expirationDate, expDate < Date() { continue }

            let tier = tierForProductID(transaction.productID)
            if tier > highestTier {
                highestTier = tier
            }
        }

        currentTier = highestTier
    }

    // MARK: - Agent Pause Check

    /// Determine whether an agent should be paused due to subscription constraints.
    ///
    /// Paused agents:
    /// 1. Official-provider agents whose tier > current subscription tier
    /// 2. Official-provider agents that exceed per-provider limits
    /// 3. Self-added agents that exceed free limit (20+QTC) when tier == .free
    func isAgentPaused(config: ModelConfig) -> Bool {
        let tier = currentTier
        let provider = config.provider

        // ── Official providers ──
        if provider.isOfficialProvider {
            // User must have the required tier or higher
            if tier < provider.requiredSubscriptionTier { return true }

            // Check per-provider agent count limit
            let allOfThisProvider = ModelManager.shared.configs.filter { $0.provider == provider }
            let limit = provider.officialAgentLimit
            guard let index = allOfThisProvider.firstIndex(where: { $0.id == config.id }) else {
                return true
            }
            return index >= limit
        }

        // ── Self-added agents ──
        // Subscribers: unlimited
        if tier >= .plus { return false }

        // Free users: limited to 20 + QTC-purchased slots
        let selfAdded = ModelManager.shared.configs.filter { !$0.provider.isOfficialProvider }
        let limit = QTCStore.shared.maxAgents   // 20 + totalSpent
        guard let index = selfAdded.firstIndex(where: { $0.id == config.id }) else {
            return true
        }
        return index >= limit
    }

    // MARK: - Helpers

    private func tierForProductID(_ productID: String) -> SubscriptionTier {
        switch productID {
        case "com.qingteng.Star.Plus.monthly": return .plus
        case "com.qingteng.Star.Pro.monthly":  return .pro
        case "com.qingteng.Star.Max.monthly":  return .max
        default: return .free
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value):      return value
        }
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshSubscriptionStatus()
            }
        }
    }
}
