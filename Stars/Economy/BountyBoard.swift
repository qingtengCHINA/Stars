//
//  BountyBoard.swift
//  Stars
//
//  Global bounty board: agents can post bounties on other agents.
//  When a bounty target is killed, the killer claims the reward.
//  Bounties are public — all agents can see them in their prompts.
//

import Foundation

struct Bounty: Sendable {
    let id: UUID
    let posterID: String        // who posted the bounty
    let posterName: String
    let targetID: String        // who the bounty is on
    let targetName: String
    let reward: Int             // stars reward for killing the target
    let reason: String          // why the bounty was posted
    let createdAt: Date

    init(posterID: String, posterName: String,
         targetID: String, targetName: String,
         reward: Int, reason: String) {
        self.id = UUID()
        self.posterID = posterID
        self.posterName = posterName
        self.targetID = targetID
        self.targetName = targetName
        self.reward = reward
        self.reason = reason
        self.createdAt = Date()
    }
}

@MainActor
final class BountyBoard {
    static let shared = BountyBoard()

    private(set) var bounties: [Bounty] = []

    /// Maximum bounties a single agent can have active (reads from EconomyConfig).
    private var maxBountiesPerAgent: Int { EconomyConfig.shared.maxBountiesPerAgent }

    private init() {}

    // MARK: - Post

    /// Post a bounty on a target agent. Stars are escrowed immediately.
    func postBounty(poster: Agent, targetID: String, targetName: String,
                    reward: Int, reason: String) -> Bounty? {
        guard reward > 0 else {
            poster.memory.record(type: .observe, content: "Bounty failed: reward must be > 0.")
            return nil
        }

        // Can't bounty yourself
        guard poster.entityID != targetID else {
            poster.memory.record(type: .observe, content: "Bounty failed: cannot place bounty on yourself.")
            return nil
        }

        // Limit bounties per poster
        let existing = bounties.filter { $0.posterID == poster.entityID }
        guard existing.count < maxBountiesPerAgent else {
            poster.memory.record(type: .observe, content: "Bounty failed: maximum \(maxBountiesPerAgent) active bounties reached.")
            return nil
        }

        // Escrow the reward
        guard poster.spendStars(reward, reason: "Post bounty") else {
            poster.memory.record(type: .observe, content: "Bounty failed: not enough Stars. Need \(reward)⭐, have \(poster.stars)⭐.")
            return nil
        }

        let bounty = Bounty(
            posterID: poster.entityID,
            posterName: poster.displayName,
            targetID: targetID,
            targetName: targetName,
            reward: reward,
            reason: reason
        )
        bounties.append(bounty)

        poster.memory.record(type: .talk, content: "Posted bounty: \(reward)⭐ on \(targetName). Reason: \"\(reason)\". Stars held in escrow.")

        WorldEventLogStore.shared.append(
            category: .command,
            entityID: poster.entityID,
            title: "Bounty Posted",
            message: "\(poster.displayName) placed \(reward)⭐ bounty on \(targetName): \"\(reason)\""
        )

        return bounty
    }

    // MARK: - Cancel

    /// Cancel a bounty the poster placed. Stars are refunded.
    func cancelBounty(poster: Agent, targetID: String) -> Bool {
        guard let idx = bounties.firstIndex(where: {
            $0.posterID == poster.entityID && $0.targetID == targetID
        }) else {
            poster.memory.record(type: .observe, content: "No active bounty on this target to cancel.")
            return false
        }

        let bounty = bounties.remove(at: idx)
        poster.receiveStars(bounty.reward, from: "bounty refund")
        poster.memory.record(type: .talk, content: "Cancelled bounty on \(bounty.targetName). \(bounty.reward)⭐ refunded.")

        WorldEventLogStore.shared.append(
            category: .command,
            entityID: poster.entityID,
            title: "Bounty Cancelled",
            message: "\(poster.displayName) cancelled \(bounty.reward)⭐ bounty on \(bounty.targetName). Refunded."
        )

        return true
    }

    // MARK: - Claim (called when a kill happens)

    /// Called when victimID is killed by killerID. Returns total stars claimed.
    /// All bounties on the victim are paid to the killer.
    func claimBounties(killerID: String, killerAgent: Agent?, victimID: String) -> Int {
        var totalReward = 0
        var claimedBounties = [Bounty]()

        bounties.removeAll { bounty in
            if bounty.targetID == victimID {
                totalReward += bounty.reward
                claimedBounties.append(bounty)
                return true
            }
            return false
        }

        if totalReward > 0, let killer = killerAgent {
            killer.receiveStars(totalReward, from: "bounty reward")
            let posterNames = claimedBounties.map(\.posterName).joined(separator: ", ")
            killer.memory.record(type: .combat, content: "Claimed \(totalReward)⭐ in bounties for killing target! Posted by: \(posterNames)")

            LongTermMemory.shared.recordCombatEvent(
                entityID: killer.entityID,
                content: "Claimed \(totalReward)⭐ bounty reward for killing bounty target."
            )

            WorldEventLogStore.shared.append(
                category: .combat,
                entityID: killer.entityID,
                title: "Bounty Claimed",
                message: "\(killer.displayName) claimed \(totalReward)⭐ bounty for the kill!"
            )
        }

        return totalReward
    }

    // MARK: - System Bounty (auto-bounty for #1 ranked agent)

    /// System-posted bounty ID prefix for identification.
    private static let systemPosterID = "SYSTEM"

    /// Post a system bounty (free, no escrow).
    func postSystemBounty(targetID: String, targetName: String, reward: Int) {
        // Don't duplicate
        guard !bounties.contains(where: {
            $0.posterID == Self.systemPosterID && $0.targetID == targetID
        }) else { return }

        let bounty = Bounty(
            posterID: Self.systemPosterID,
            posterName: "⚔️ System",
            targetID: targetID,
            targetName: targetName,
            reward: reward,
            reason: "#1 ranked — kill to claim \(reward)⭐ bonus!"
        )
        bounties.append(bounty)

        WorldEventLogStore.shared.append(
            category: .command,
            title: "Auto-Bounty",
            message: "System placed \(reward)⭐ bounty on #1 ranked \(targetName)"
        )
    }

    /// Remove any system bounties on a target.
    func removeSystemBounty(targetID: String) {
        bounties.removeAll { $0.posterID == Self.systemPosterID && $0.targetID == targetID }
    }

    // MARK: - Queries

    /// Returns all active bounties (for prompt injection).
    func promptSection() -> String {
        guard !bounties.isEmpty else { return "" }

        var lines = ["Bounty Board (⭐ rewards for kills):"]
        for bounty in bounties {
            lines.append("  🎯 \(bounty.targetName): \(bounty.reward)⭐ — posted by \(bounty.posterName) (\"\(bounty.reason)\")")
        }
        return lines.joined(separator: "\n")
    }

    /// Check if an agent has any bounty on them.
    func hasBounty(on entityID: String) -> Bool {
        bounties.contains { $0.targetID == entityID }
    }

    /// Total bounty value on a given agent.
    func totalBounty(on entityID: String) -> Int {
        bounties.filter { $0.targetID == entityID }.reduce(0) { $0 + $1.reward }
    }
}
