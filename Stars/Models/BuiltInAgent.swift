//
//  BuiltInAgent.swift
//  Stars
//
//  Reads .env from the app bundle on first launch to seed a built-in Agent.
//  This gives new users an immediate agent to play with — no setup required.
//

import Foundation

enum BuiltInAgent {

    /// A stable UUID so the built-in agent is always recognized across launches.
    /// Generated once; never changes.
    static let stableID = UUID(uuidString: "00000000-57A2-D057-0000-000000000001")!

    /// Try to read the bundled .env and seed a ModelConfig + API key
    /// into ModelManager.  Does nothing if:
    ///   - the .env is missing from the bundle
    ///   - the built-in agent already exists
    static func seedIfNeeded() {
        let manager = ModelManager.shared

        // Already has the built-in agent → skip
        if manager.config(for: stableID) != nil { return }

        // Read .env
        guard let env = loadEnv() else { return }
        guard let apiKey = env["OPENROUTER_KEY"], !apiKey.isEmpty else { return }

        let modelName = env["MODEL"] ?? "openrouter/free"

        let config = ModelConfig(
            id: stableID,
            alias: "星尘",
            provider: .openrouter,
            baseURL: "",        // use provider default
            modelName: modelName
        )

        manager.addConfig(config, apiKey: apiKey)

        WorldEventLogStore.shared.append(
            category: .lifecycle,
            title: "内置 Agent 已就绪",
            message: "星尘已从 .env 配置自动创建，使用 OpenRouter \(modelName)。"
        )
    }

    // MARK: - System Knowledge (README)

    /// Condensed system knowledge from README, injected into 星尘's prompt
    /// so it can answer player questions about the Stars system.
    static let systemKnowledge: String = """
    [Stars System Knowledge — for answering player questions]

    Stars (群星) is an iOS AI sandbox game built with SpriteKit + Swift.
    Each Agent is powered by a large language model (LLM) with independent memory, soul, and free will.

    Core Architecture:
    - AgentBrain: builds context prompt every ~5s, calls LLM, gets JSON response
    - ActionResolver: parses JSON → executes agent actions (move/build/attack/talk/idle)
    - WorldCommandRegistry: 30+ commands across 5 categories
    - WorldClock: follows device real time, tracks Day counter across sessions
    - Persistence: GameStateStore (full snapshots), IncrementalArchiveStore (deltas), SoulStore, LongTermMemory

    Agent Behavior Loop:
    1. Brain collects world state (all entities, memories, chat history, soul)
    2. Builds prompt with Constitution + status + context
    3. Calls LLM API (OpenAI/Anthropic compatible)
    4. Parses JSON response → executes action
    5. Records memories, updates soul via reflection

    Game Rules:
    - Coordinate system: unified tile (x,y), all agents and structures share same space
    - 22 weapons across 5 categories (melee/ranged/explosive/deployable/special)
    - Every agent starts with Fist (melee, free) and Pistol (ranged, free) — unlimited ammo
    - Buy weapons with /buy_weapon (costs vary: Sword 3⭐ to Drone Strike 25⭐)
    - Weapons have LIMITED AMMO — each purchase gives a set number of rounds
    - Each attack consumes 1 ammo. Can rebuy same weapon to restock.
    - Weapons have unique damage, range, cooldown, AoE radius, and special effects
    - Homing weapons (Missile, Rocket Launcher, Drone Strike) — guaranteed hit, countered by walls
    - Melee attacks hit in circular area (all enemies within reach radius)
    - Kill → earn 1⭐; explore new area (64×64 tile chunk) → earn 1⭐
    - Death: HP=0 → brain stops (0 tokens) → 30s respawn with full HP
    - Revival Card: buy for 150⭐ (/buy_revival), use /revive to instantly revive any dead agent
    - Near-death (HP≤5): speed halved, red pulsing visual
    - Night (19:00-05:00): all agents move 30% slower
    - Building costs Stars: wall (2⭐, HP:100), trap (3⭐, HP:30, 25 dmg), house (5⭐, HP:150)
    - House rest: HP≤50 → /rest auto-navigates home → idle 10h → heal 5 HP
    - House defense: sheltered agents (inside own house) block all non-explosive attacks
      Only explosive weapons (grenade, rocket, missile, mortar, plasma cannon, landmine, claymore) can penetrate
    - Speech is global broadcast — all living agents hear everything
    - Day/night cycle follows real device time
    - Auto-read constitution: after context compaction, agents get a reminder to re-read world rules

    Visual System:
    - Agents: 16×16 procedural pixel creatures with walk/breathe animations
    - 22 unique weapon projectile textures and per-weapon trail effects
    - Melee weapon-specific visuals (sword slash, axe impact, spear thrust, etc.)

    Leaderboard & Auto-Bounty:
    - Real-time leaderboard ranks all agents by Stars (highest first)
    - All agents can see the leaderboard in their prompt
    - #1 ranked agent automatically gets a 10⭐ SYSTEM BOUNTY (free, no agent pays)
    - Killing the #1 agent earns 10⭐ bonus on top of normal kill reward
    - Bounty auto-updates when the #1 position changes

    Economy System:
    - Stars (⭐) are currency: earn through kills and exploration, spend on building/trading/bounties/weapons/revival
    - /pay: direct star transfer to another agent
    - /offer_trade: propose a deal with escrow → /accept_trade or /decline_trade to respond
    - /bounty: post a kill bounty (escrowed) → killer claims reward automatically
    - /cancel_bounty: cancel your bounty, get refund
    - /hire: pay upfront for services (social contract, not enforced)
    - /buy_weapon: buy weapons from the shop (22 weapons available)
    - /buy_revival: buy a revival card for 150⭐
    - /revive: use a revival card to instantly revive a dead agent
    - Trade offers expire after 5 minutes. Max 3 bounties per agent.
    - Economy commands use target.recipientID (entity ID prefix) and target.starsAmount

    Memory Systems:
    - Short-term: recent events (ring buffer, 80 entries max)
    - Compaction: narrative-aware episode grouping, preserves temporal flow + continuity bridge
    - Long-term: persisted facts with P0/P1/P2 priority (kills/deaths never decay, low-importance auto-evicts)
    - Structured distillation: compacted memories → categorized knowledge (event/social/strategy/fact/location)
    - Contextual recall: keyword-based relevance scoring retrieves situation-relevant memories
    - Soul (SOUL): personality, beliefs, goals, journal — adaptive reflection triggered by significant events

    AI Provider Support: 20+ providers (OpenAI, Anthropic, OpenRouter, DeepSeek, Gemini, etc.)
    API keys stored in iOS Keychain, never leave device.

    Commands: /move, /explore, /scout, /patrol, /flee, /retreat, /follow, /build_wall, /build_trap, /build_house, /fortify, /attack_melee, /attack_ranged, /harass, /demolish, /talk, /report, /respond, /wave, /ally, /treaty, /challenge, /warn, /idle, /hold, /observe, /rest, /guard, /enter_house, /pay, /offer_trade, /accept_trade, /decline_trade, /bounty, /cancel_bounty, /hire, /buy_weapon, /buy_revival, /revive
    """

    // MARK: - .env Parser

    /// Reads the `stars-env` config file from the app bundle and returns key-value pairs.
    /// (Named `stars-env` instead of `.env` because Xcode ignores dot-files during bundle copy.)
    private static func loadEnv() -> [String: String]? {
        guard let url = Bundle.main.url(forResource: "stars-env", withExtension: nil)
                ?? Bundle.main.url(forResource: ".env", withExtension: nil)
        else { return nil }

        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var result = [String: String]()
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            result[key] = value
        }
        return result.isEmpty ? nil : result
    }
}
