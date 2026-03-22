//
//  EconomyFile.swift
//  Stars
//
//  Player-editable economy rules — defines the economic system that
//  every agent receives in their prompt.  Players can modify trade rules,
//  bounty mechanics, pricing, and more to reshape the world's economy.
//
//  The [CONFIG] block at the end is parsed by EconomyConfig to apply
//  real gameplay parameter changes (not just prompt text).
//

import Foundation

extension Notification.Name {
    static let starsEconomyDidUpdate = Notification.Name("stars.economyDidUpdate")
}

@MainActor
final class EconomyFile {
    static let shared = EconomyFile()

    private let storageKey = "stars.economy.file"

    /// The raw text of the player-editable economy rules.
    private(set) var content: String

    private init() {
        if let saved = UserDefaults.standard.string(forKey: storageKey), !saved.isEmpty {
            content = saved
        } else {
            content = Self.defaultContent
        }
        // Apply config from saved content on launch
        EconomyConfig.shared.applyFromText(content)
    }

    func update(_ newContent: String) {
        content = newContent
        UserDefaults.standard.set(newContent, forKey: storageKey)
        // Parse [CONFIG] block and apply real gameplay changes
        EconomyConfig.shared.applyFromText(newContent)
        NotificationCenter.default.post(name: .starsEconomyDidUpdate, object: nil)
    }

    func reset() {
        update(Self.defaultContent)
    }

    /// Formatted section for injection into agent prompts.
    var promptSection: String {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return """
        === ECONOMY RULES (经济系统) ===
        \(content)
        === END ECONOMY RULES ===
        """
    }

    // MARK: - Default Content

    static let defaultContent = """
    ## Economy & Trade (经济与贸易)

    Stars (⭐) are the universal currency of this world.

    ### Earning Stars
    - Kill another agent: +1⭐
    - Explore a new area (unvisited chunk): +1⭐
    - Accept trade offers or get hired by other agents

    ### Spending Stars
    - Building costs Stars: wall = 2⭐, trap = 3⭐, house = 5⭐
    - /pay: send stars directly to another agent (no confirmation needed)
    - /hire: pay an agent upfront to do a task. Describe the task in speech.
    - /bounty: post a kill bounty on another agent. Stars are escrowed.

    ### Trading
    - /offer_trade: propose a deal — pay stars in exchange for a service or favor.
      Stars are held in escrow until the recipient accepts or declines.
    - /accept_trade: accept a pending trade offer. The escrowed stars transfer to you.
    - /decline_trade: decline a pending trade offer. Stars are refunded to the offeror.
    - Trade offers expire after 5 minutes if not accepted.

    ### Bounty Board
    - /bounty: post a public bounty. All agents see it. Stars are escrowed.
    - When the bounty target is killed, the killer receives ALL bounty rewards.
    - /cancel_bounty: cancel your own bounty. Stars are refunded.
    - Multiple agents can post bounties on the same target (rewards stack).
    - Maximum 3 active bounties per agent.

    ### Hiring
    - /hire: pay another agent upfront for a task. The payment is immediate.
    - Hiring is a social contract, not system-enforced. The hired agent chooses whether to comply.
    - Use speech to describe what you want them to do.

    ### Economic Strategy
    - Stars are finite. Spend wisely — building, trading, and bounties all cost stars.
    - Agents start with 0⭐. Earn through combat and exploration.
    - Rich agents have more options: they can hire allies, post bounties, and build more.
    - Poor agents must earn through exploration or combat before they can build or trade.
    - All economy commands use target.recipientID (entity ID prefix of the target agent) and target.starsAmount.

    ---

    ## Leaderboard & Bounty (排行榜与悬赏)

    A real-time leaderboard tracks all agents ranked by Stars (highest first).
    - The leaderboard is visible to ALL agents in their prompt context.
    - Rank #1 agent automatically receives a SYSTEM BOUNTY.
      • This bounty is FREE — no agent pays for it. The system creates it automatically.
      • Any agent who kills the #1 ranked agent earns bonus Stars on top of the normal kill reward.
      • This encourages competition and prevents runaway leaders.
      • The bounty updates automatically when the #1 position changes.
    - Being #1 is both a privilege and a danger. Consider the risk.
    - The leaderboard is a tool for strategy: know who's strong, who's weak, who's a threat.
    - Dead agents appear on the leaderboard with 💀.
    \(EconomyConfig.defaultConfigBlock)
    """
}
