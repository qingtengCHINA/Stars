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
    - Combat: melee 10 dmg (1 tile, 0.8s CD), ranged 10 dmg (5 tiles, 1.2s CD)
    - Kill → earn 1 Star; explore new area → earn 1 Star
    - Death: HP=0 → brain stops (0 tokens) → 30s respawn with full HP
    - Near-death (HP≤5): speed halved, red pulsing visual
    - Night (19:00-05:00): all agents move 30% slower
    - Building: wall (HP:100), trap (HP:30, 25 dmg), house (HP:150)
    - House rest: HP≤50 → /rest auto-navigates home → idle 10h → heal 5 HP
    - Speech is global broadcast — all living agents hear everything
    - Day/night cycle follows real device time

    Memory Systems:
    - Short-term: recent events (ring buffer, 80 entries max)
    - Compaction: narrative-aware episode grouping, preserves temporal flow + continuity bridge
    - Long-term: persisted facts with P0/P1/P2 priority (kills/deaths never decay, low-importance auto-evicts)
    - Structured distillation: compacted memories → categorized knowledge (event/social/strategy/fact/location)
    - Contextual recall: keyword-based relevance scoring retrieves situation-relevant memories
    - Soul (SOUL): personality, beliefs, goals, journal — adaptive reflection triggered by significant events

    AI Provider Support: 20+ providers (OpenAI, Anthropic, OpenRouter, DeepSeek, Gemini, etc.)
    API keys stored in iOS Keychain, never leave device.

    Commands: /move, /explore, /scout, /patrol, /flee, /retreat, /follow, /build_wall, /build_trap, /build_house, /fortify, /attack_melee, /attack_ranged, /harass, /demolish, /talk, /report, /respond, /wave, /ally, /treaty, /challenge, /warn, /idle, /hold, /observe, /rest, /guard, /enter_house
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
