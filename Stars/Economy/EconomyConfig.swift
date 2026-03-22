//
//  EconomyConfig.swift
//  Stars
//
//  Centralized economy configuration — all tunable values in one place.
//  When the player edits the Economy System, the [CONFIG] block at the
//  end of the text is parsed and applied here.  Every game system reads
//  from EconomyConfig instead of using hardcoded constants.
//

import Foundation

@MainActor
final class EconomyConfig {
    static let shared = EconomyConfig()

    // MARK: - Reward Parameters

    /// Minimum stars earned when killing another agent.
    /// Actual reward = max(killReward, victim's stars × killRewardPercent / 100).
    var killReward: Int = 1

    /// Percentage of victim's stars awarded as kill reward (default 50%).
    var killRewardPercent: Int = 50

    /// Stars earned when discovering a new map chunk.
    var explorationReward: Int = 1

    // MARK: - Building Costs

    /// Cost to build a wall.
    var wallCost: Int = 2

    /// Cost to build a trap.
    var trapCost: Int = 3

    /// Cost to build a house.
    var houseCost: Int = 5

    // MARK: - Structure Stats

    /// HP of a wall.
    var wallHP: Int = 100

    /// HP of a trap.
    var trapHP: Int = 30

    /// Damage dealt by a trap.
    var trapDamage: Int = 25

    /// HP of a house.
    var houseHP: Int = 150

    // MARK: - Special Items

    /// Cost of a Revival Card.
    var revivalCardCost: Int = 150

    /// Reward for the system bounty on #1 ranked agent.
    var systemBountyReward: Int = 10

    /// Maximum active bounties per agent.
    var maxBountiesPerAgent: Int = 3

    /// Trade offer expiration in seconds.
    var tradeExpiration: TimeInterval = 300  // 5 minutes

    // MARK: - Death & Respawn

    /// Respawn wait time in seconds.
    var respawnTime: TimeInterval = 30

    /// HP threshold for house rest eligibility.
    var houseRestHPThreshold: Int = 50

    /// HP healed after resting in house.
    var houseRestHealAmount: Int = 5

    // MARK: - Parsing

    /// Parse [CONFIG] block from the economy file text and apply values.
    /// Unknown keys are silently ignored — only known keys are applied.
    func applyFromText(_ text: String) {
        // Reset to defaults first
        resetToDefaults()

        // Find [CONFIG] block
        guard let configRange = text.range(of: "[CONFIG]") else { return }
        let configText = String(text[configRange.upperBound...])

        // Also support [/CONFIG] as end marker (optional)
        let endMarker = configText.range(of: "[/CONFIG]")
        let parseText = endMarker != nil ? String(configText[..<endMarker!.lowerBound]) : configText

        for line in parseText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("//") else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespaces).lowercased()
            let rawValue = String(parts[1]).trimmingCharacters(in: .whitespaces)

            if let intVal = Int(rawValue) {
                applyInt(key: key, value: intVal)
            } else if let doubleVal = Double(rawValue) {
                applyDouble(key: key, value: doubleVal)
            }
        }
    }

    private func applyInt(key: String, value: Int) {
        switch key {
        case "kill_reward":             killReward = max(0, value)
        case "kill_reward_percent":     killRewardPercent = max(0, min(100, value))
        case "exploration_reward":      explorationReward = max(0, value)
        case "wall_cost":               wallCost = max(0, value)
        case "trap_cost":               trapCost = max(0, value)
        case "house_cost":              houseCost = max(0, value)
        case "wall_hp":                 wallHP = max(1, value)
        case "trap_hp":                 trapHP = max(1, value)
        case "trap_damage":             trapDamage = max(0, value)
        case "house_hp":                houseHP = max(1, value)
        case "revival_card_cost":       revivalCardCost = max(0, value)
        case "system_bounty_reward":    systemBountyReward = max(0, value)
        case "max_bounties_per_agent":  maxBountiesPerAgent = max(1, value)
        case "respawn_time":            respawnTime = max(1, TimeInterval(value))
        case "house_rest_hp_threshold": houseRestHPThreshold = max(1, value)
        case "house_rest_heal":         houseRestHealAmount = max(1, value)
        default: break
        }
    }

    private func applyDouble(key: String, value: Double) {
        switch key {
        case "trade_expiration":        tradeExpiration = max(10, value)
        case "respawn_time":            respawnTime = max(1, value)
        default:
            // Try as int too
            applyInt(key: key, value: Int(value))
        }
    }

    func resetToDefaults() {
        killReward = 1
        killRewardPercent = 50
        explorationReward = 1
        wallCost = 2
        trapCost = 3
        houseCost = 5
        wallHP = 100
        trapHP = 30
        trapDamage = 25
        houseHP = 150
        revivalCardCost = 150
        systemBountyReward = 10
        maxBountiesPerAgent = 3
        tradeExpiration = 300
        respawnTime = 30
        houseRestHPThreshold = 50
        houseRestHealAmount = 5
    }

    /// Generate the default [CONFIG] block text for display.
    static let defaultConfigBlock = """

    ---
    [CONFIG]
    # 以下参数可以自由修改，保存后立即生效
    # These parameters can be freely modified, effective immediately after saving

    # 奖励 / Rewards
    kill_reward = 1
    kill_reward_percent = 50
    exploration_reward = 1

    # 建造费用 / Building Costs
    wall_cost = 2
    trap_cost = 3
    house_cost = 5

    # 建筑属性 / Structure Stats
    wall_hp = 100
    trap_hp = 30
    trap_damage = 25
    house_hp = 150

    # 特殊物品 / Special Items
    revival_card_cost = 150
    system_bounty_reward = 10
    max_bounties_per_agent = 3

    # 死亡与重生 / Death & Respawn
    respawn_time = 30
    house_rest_hp_threshold = 50
    house_rest_heal = 5

    # 交易 / Trade
    trade_expiration = 300
    [/CONFIG]
    """

    private init() {}
}
