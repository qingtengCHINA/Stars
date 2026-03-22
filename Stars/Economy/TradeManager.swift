//
//  TradeManager.swift
//  Stars
//
//  Two-phase trade system: offer → accept / decline.
//  Trades are between agents and expire after a timeout.
//  All trade commands map to action: talk (speech-based negotiation).
//

import Foundation

struct TradeOffer: Sendable {
    let id: UUID
    let offerorID: String       // entityID of the agent offering
    let offerorName: String
    let recipientID: String     // entityID of the target agent
    let recipientName: String
    let starsAmount: Int        // stars being offered
    let description: String     // what the offeror wants in return (free-text)
    let createdAt: Date

    init(offerorID: String, offerorName: String,
         recipientID: String, recipientName: String,
         starsAmount: Int, description: String) {
        self.id = UUID()
        self.offerorID = offerorID
        self.offerorName = offerorName
        self.recipientID = recipientID
        self.recipientName = recipientName
        self.starsAmount = starsAmount
        self.description = description
        self.createdAt = Date()
    }
}

@MainActor
final class TradeManager {
    static let shared = TradeManager()

    private(set) var pendingTrades: [TradeOffer] = []

    /// How long a trade offer stays valid (reads from EconomyConfig).
    private var tradeExpirationInterval: TimeInterval { EconomyConfig.shared.tradeExpiration }

    private init() {}

    // MARK: - Offer

    /// Create a trade offer. The offeror's stars are held in escrow immediately.
    /// Returns nil if the offeror cannot afford the trade or recipient not found.
    func createOffer(
        offeror: Agent,
        recipientID: String,
        recipientName: String,
        starsAmount: Int,
        description: String
    ) -> TradeOffer? {
        guard starsAmount > 0 else {
            offeror.memory.record(type: .observe, content: "Trade failed: invalid star amount.")
            return nil
        }

        // Check if offeror has enough stars
        guard offeror.spendStars(starsAmount, reason: "Trade offer") else {
            offeror.memory.record(type: .observe, content: "Trade failed: not enough Stars. Need \(starsAmount)⭐, have \(offeror.stars)⭐.")
            return nil
        }

        let offer = TradeOffer(
            offerorID: offeror.entityID,
            offerorName: offeror.displayName,
            recipientID: recipientID,
            recipientName: recipientName,
            starsAmount: starsAmount,
            description: description
        )
        pendingTrades.append(offer)

        offeror.memory.record(type: .talk, content: "Offered \(starsAmount)⭐ trade to \(recipientName): \"\(description)\". Stars held in escrow.")

        WorldEventLogStore.shared.append(
            category: .command,
            entityID: offeror.entityID,
            title: "Trade Offered",
            message: "\(offeror.displayName) → \(recipientName): \(starsAmount)⭐ for \"\(description)\""
        )

        return offer
    }

    // MARK: - Accept

    /// Accept a pending trade. Stars transfer to the recipient.
    func acceptTrade(acceptor: Agent, offerorID: String) -> Bool {
        guard let idx = pendingTrades.firstIndex(where: {
            $0.recipientID == acceptor.entityID && $0.offerorID == offerorID
        }) else {
            acceptor.memory.record(type: .observe, content: "No pending trade from this agent.")
            return false
        }

        let offer = pendingTrades.remove(at: idx)

        // Transfer escrowed stars to acceptor
        acceptor.receiveStars(offer.starsAmount, from: offer.offerorName)
        acceptor.memory.record(type: .talk, content: "Accepted trade from \(offer.offerorName): received \(offer.starsAmount)⭐ for \"\(offer.description)\".")

        // Record in long-term memory for both parties
        LongTermMemory.shared.recordSocialFact(
            entityID: acceptor.entityID,
            content: "Traded with \(offer.offerorName): received \(offer.starsAmount)⭐ for \"\(offer.description)\"."
        )
        LongTermMemory.shared.recordSocialFact(
            entityID: offer.offerorID,
            content: "Trade with \(offer.recipientName) completed: paid \(offer.starsAmount)⭐ for \"\(offer.description)\"."
        )

        WorldEventLogStore.shared.append(
            category: .command,
            entityID: acceptor.entityID,
            title: "Trade Accepted",
            message: "\(acceptor.displayName) accepted \(offer.offerorName)'s offer: \(offer.starsAmount)⭐"
        )

        return true
    }

    // MARK: - Decline

    /// Decline a pending trade. Stars are refunded to the offeror.
    func declineTrade(decliner: Agent, offerorID: String, refundTo: Agent?) -> Bool {
        guard let idx = pendingTrades.firstIndex(where: {
            $0.recipientID == decliner.entityID && $0.offerorID == offerorID
        }) else {
            decliner.memory.record(type: .observe, content: "No pending trade to decline from this agent.")
            return false
        }

        let offer = pendingTrades.remove(at: idx)

        // Refund escrowed stars — if the offeror is not found, re-insert
        // the trade so the expiry system can refund them later.
        if let refundTo {
            refundTo.receiveStars(offer.starsAmount, from: "trade refund")
        } else {
            pendingTrades.insert(offer, at: idx)
            decliner.memory.record(type: .observe, content: "Cannot decline: offeror not found for refund.")
            return false
        }

        decliner.memory.record(type: .talk, content: "Declined trade from \(offer.offerorName): \(offer.starsAmount)⭐ for \"\(offer.description)\". Stars refunded.")

        WorldEventLogStore.shared.append(
            category: .command,
            entityID: decliner.entityID,
            title: "Trade Declined",
            message: "\(decliner.displayName) declined \(offer.offerorName)'s offer. \(offer.starsAmount)⭐ refunded."
        )

        return true
    }

    // MARK: - Direct Payment

    /// Direct star transfer between agents (no confirmation needed).
    func pay(from sender: Agent, to recipient: Agent, amount: Int) -> Bool {
        guard amount > 0 else { return false }
        guard sender.spendStars(amount, reason: "Pay \(recipient.displayName)") else {
            sender.memory.record(type: .observe, content: "Payment failed: not enough Stars. Need \(amount)⭐, have \(sender.stars)⭐.")
            return false
        }

        recipient.receiveStars(amount, from: sender.displayName)

        sender.memory.record(type: .talk, content: "Paid \(amount)⭐ to \(recipient.displayName). Remaining: \(sender.stars)⭐.")

        LongTermMemory.shared.recordSocialFact(
            entityID: sender.entityID,
            content: "Paid \(amount)⭐ to \(recipient.displayName)."
        )
        LongTermMemory.shared.recordSocialFact(
            entityID: recipient.entityID,
            content: "Received \(amount)⭐ payment from \(sender.displayName)."
        )

        WorldEventLogStore.shared.append(
            category: .command,
            entityID: sender.entityID,
            title: "Payment Sent",
            message: "\(sender.displayName) → \(recipient.displayName): \(amount)⭐"
        )

        return true
    }

    // MARK: - Expiration

    /// Remove expired trades and refund escrowed stars.
    /// Call periodically from AgentManager.update().
    func expireOldTrades(agentLookup: (String) -> Agent?) {
        let now = Date()
        var expired = [TradeOffer]()

        pendingTrades.removeAll { offer in
            if now.timeIntervalSince(offer.createdAt) > tradeExpirationInterval {
                expired.append(offer)
                return true
            }
            return false
        }

        for offer in expired {
            // Refund escrowed stars to offeror
            if let offeror = agentLookup(offer.offerorID) {
                offeror.receiveStars(offer.starsAmount, from: "expired trade refund")
                offeror.memory.record(type: .observe, content: "Trade offer to \(offer.recipientName) expired. \(offer.starsAmount)⭐ refunded.")
            }

            WorldEventLogStore.shared.append(
                category: .command,
                title: "Trade Expired",
                message: "\(offer.offerorName) → \(offer.recipientName): \(offer.starsAmount)⭐ offer expired. Refunded."
            )
        }
    }

    // MARK: - Queries

    /// Returns pending trades where the given agent is the recipient.
    func pendingOffersFor(entityID: String) -> [TradeOffer] {
        pendingTrades.filter { $0.recipientID == entityID }
    }

    /// Returns pending trades where the given agent is the offeror.
    func pendingOffersFrom(entityID: String) -> [TradeOffer] {
        pendingTrades.filter { $0.offerorID == entityID }
    }

    /// Prompt section showing pending trades for an agent.
    func promptSection(for entityID: String) -> String {
        let incoming = pendingOffersFor(entityID: entityID)
        let outgoing = pendingOffersFrom(entityID: entityID)
        guard !incoming.isEmpty || !outgoing.isEmpty else { return "" }

        var lines = ["Pending trades:"]
        for offer in incoming {
            lines.append("  📥 From \(offer.offerorName): \(offer.starsAmount)⭐ for \"\(offer.description)\" — use /accept_trade or /decline_trade with recipientID \"\(offer.offerorID.prefix(8))\"")
        }
        for offer in outgoing {
            lines.append("  📤 To \(offer.recipientName): \(offer.starsAmount)⭐ for \"\(offer.description)\" (waiting for response)")
        }
        return lines.joined(separator: "\n")
    }
}
