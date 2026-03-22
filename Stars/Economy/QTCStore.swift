//
//  QTCStore.swift
//  Stars
//
//  Manages QTC (QingTeng Credits) balance and transaction history.
//  Persists via NSUbiquitousKeyValueStore (iCloud, tied to Apple ID)
//  with UserDefaults fallback when iCloud is unavailable.
//
//  QTC is used to unlock additional Agent slots beyond the free limit (20).
//  1 QTC = 1 extra Agent slot.
//

import Foundation

/// Records a single QTC transaction for the dashboard.
struct QTCTransaction: Codable {
    let timestamp: TimeInterval
    let amount: Int          // positive = earned/purchased, negative = spent
    let reason: String       // human-readable description
    let balance: Int         // QTC balance after this transaction
}

@MainActor
final class QTCStore {
    static let shared = QTCStore()

    /// Free agent limit — no QTC needed for the first 20 agents.
    static let freeAgentLimit = 20

    // MARK: - Keys

    private let balanceKey   = "stars.qtc.balance"
    private let txLogKey     = "stars.qtc.transactions"
    private let spentKey     = "stars.qtc.totalSpent"

    // MARK: - State

    /// Current QTC balance.
    private(set) var balance: Int {
        didSet { persist() }
    }

    /// Transaction history (most recent 100).
    private(set) var transactions: [QTCTransaction] = []

    /// Total QTC ever spent (to compute max agents allowed).
    private(set) var totalSpent: Int

    /// Notification posted when balance changes.
    static let balanceDidChange = Notification.Name("stars.qtc.balanceDidChange")

    // MARK: - Computed

    /// Maximum number of agents the player can have.
    /// Free limit + total QTC ever spent on agent slots.
    var maxAgents: Int {
        Self.freeAgentLimit + totalSpent
    }

    /// Current agent count.
    var currentAgentCount: Int {
        ModelManager.shared.configs.count
    }

    /// Can the player add another agent for free?
    var canAddAgentFree: Bool {
        currentAgentCount < Self.freeAgentLimit
    }

    /// Can the player add another agent (free, via subscription, or with QTC)?
    var canAddAgent: Bool {
        if SubscriptionStore.shared.currentTier >= .plus { return true }
        return currentAgentCount < maxAgents || balance > 0
    }

    /// How many more free slots remain.
    var freeSlotRemaining: Int {
        max(0, Self.freeAgentLimit - currentAgentCount)
    }

    // MARK: - Init

    private init() {
        // Prefer iCloud store; fall back to UserDefaults
        let cloud = NSUbiquitousKeyValueStore.default
        cloud.synchronize()

        let cloudBalance = cloud.object(forKey: balanceKey) as? Int
        let localBalance = UserDefaults.standard.object(forKey: balanceKey) as? Int

        // Use the higher of iCloud vs local (to avoid data loss)
        self.balance = max(cloudBalance ?? 0, localBalance ?? 0)

        let cloudSpent = cloud.object(forKey: spentKey) as? Int
        let localSpent = UserDefaults.standard.object(forKey: spentKey) as? Int
        self.totalSpent = max(cloudSpent ?? 0, localSpent ?? 0)

        // Load transaction log
        if let data = cloud.data(forKey: txLogKey) ?? UserDefaults.standard.data(forKey: txLogKey),
           let decoded = try? JSONDecoder().decode([QTCTransaction].self, from: data) {
            self.transactions = decoded
        }

        // Listen for iCloud changes — must observe on main queue since
        // QTCStore is @MainActor and mutations must happen on the main thread.
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleICloudChange(notification)
            }
        }

        // Force an initial sync
        persist()
    }

    // MARK: - iCloud Sync

    private func handleICloudChange(_ notification: Notification) {
        let cloud = NSUbiquitousKeyValueStore.default
        if let cloudBal = cloud.object(forKey: balanceKey) as? Int {
            if cloudBal > balance {
                balance = cloudBal
            }
        }
        if let cloudSpent = cloud.object(forKey: spentKey) as? Int {
            if cloudSpent > totalSpent {
                totalSpent = cloudSpent
            }
        }
        if let data = cloud.data(forKey: txLogKey),
           let decoded = try? JSONDecoder().decode([QTCTransaction].self, from: data),
           decoded.count > transactions.count {
            transactions = decoded
        }
        NotificationCenter.default.post(name: Self.balanceDidChange, object: nil)
    }

    // MARK: - Add Credits (from purchase)

    /// Add QTC from a purchase. Called after StoreKit transaction is verified.
    func addCredits(_ amount: Int, reason: String) {
        guard amount > 0 else { return }
        balance += amount
        recordTransaction(amount: amount, reason: reason)
        NotificationCenter.default.post(name: Self.balanceDidChange, object: nil)
    }

    // MARK: - Spend Credits (for agent slots)

    /// Spend 1 QTC to unlock an additional agent slot.
    /// Returns true if successful.
    @discardableResult
    func spendForAgentSlot() -> Bool {
        guard balance >= 1 else { return false }
        balance -= 1
        totalSpent += 1
        recordTransaction(amount: -1, reason: NSLocalizedString("qtc.spend_agent", comment: ""))
        NotificationCenter.default.post(name: Self.balanceDidChange, object: nil)
        return true
    }

    // MARK: - Restore Purchases

    /// Called after restoring transactions — sets the balance from restored amounts.
    /// StoreKit 2 consumables can't be "restored" in the traditional sense,
    /// but we reconcile by comparing local records with iCloud.
    func reconcileFromICloud() {
        let cloud = NSUbiquitousKeyValueStore.default
        cloud.synchronize()

        if let cloudBal = cloud.object(forKey: balanceKey) as? Int, cloudBal > balance {
            balance = cloudBal
        }
        if let cloudSpent = cloud.object(forKey: spentKey) as? Int, cloudSpent > totalSpent {
            totalSpent = cloudSpent
        }
        NotificationCenter.default.post(name: Self.balanceDidChange, object: nil)
    }

    // MARK: - Persistence

    private func recordTransaction(amount: Int, reason: String) {
        let tx = QTCTransaction(
            timestamp: Date().timeIntervalSince1970,
            amount: amount,
            reason: reason,
            balance: balance
        )
        transactions.append(tx)
        if transactions.count > 100 {
            transactions.removeFirst(transactions.count - 100)
        }
        persistTransactions()
    }

    private func persist() {
        let cloud = NSUbiquitousKeyValueStore.default
        // Balance
        UserDefaults.standard.set(balance, forKey: balanceKey)
        cloud.set(balance, forKey: balanceKey)
        // Spent
        UserDefaults.standard.set(totalSpent, forKey: spentKey)
        cloud.set(totalSpent, forKey: spentKey)
        cloud.synchronize()
    }

    private func persistTransactions() {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        UserDefaults.standard.set(data, forKey: txLogKey)
        NSUbiquitousKeyValueStore.default.set(data, forKey: txLogKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}
