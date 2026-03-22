//
//  AgentManager.swift
//  Stars
//

import SpriteKit

final class AgentManager {

    /// Lightweight accessor so UI (settings screens) can read agent data
    /// without threading the manager through the navigation stack.
    static weak var current: AgentManager?

    private(set) var agents: [Agent] = []
    var buildSystem: BuildSystem?
    private weak var worldNode: SKNode?

    // MARK: - Spawn

    func attachTo(worldNode: SKNode) {
        self.worldNode = worldNode
        AgentManager.current = self

        // Wire talk broadcast before spawning
        ActionResolver.talkBroadcast = { [weak self] speaker, message in
            self?.broadcastTalk(from: speaker, message: message)
        }

        // Wire house-finding callback — lets /rest and /enter_house commands work
        ActionResolver.findOwnHouse = { [weak self] agent in
            self?.buildSystem?.findOwnHouseTile(agent)
        }

        // Wire agent lookup for economy commands (prefix match)
        ActionResolver.agentLookup = { [weak self] prefix in
            self?.resolveAgentByPrefix(prefix)
        }

        // Wire revive callback for Revival Cards
        ActionResolver.reviveAgent = { [weak self] deadAgent in
            self?.forceRevive(deadAgent)
        }
    }

    func syncAgents(spawnOrigin: CGPoint = .zero) {
        guard let worldNode else { return }

        let configs = ModelManager.shared.configs
        let configByID = Dictionary(uniqueKeysWithValues: configs.map { ($0.id, $0) })
        let configIDs = Set(configByID.keys)

        for agent in agents where !configIDs.contains(agent.representedModelConfigID) {
            removeAgent(agent)
        }

        for config in configs {
            if let existing = agents.first(where: { $0.representedModelConfigID == config.id }) {
                existing.updateIdentity(displayName: config.alias, modelConfigID: config.id)
                if let brain = existing.brain {
                    brain.modelConfigID = config.id
                    brain.nearbyEntitiesProvider = { [weak self] excludeID, position, radius in
                        self?.allEntitiesNear(position, tileRadius: radius, excludingID: excludeID) ?? []
                    }
                    brain.leaderboardProvider = { [weak self] in
                        self?.agents.map {
                            (name: $0.displayName, stars: $0.stars, isDead: $0.isDead, entityID: $0.entityID)
                        } ?? []
                    }
                    existing.nearestAgentProvider = { [weak self] targetPoint, excludeID in
                        self?.nearestLivingAgent(to: targetPoint, excludingID: excludeID)
                    }
                } else {
                    assignBrain(to: existing, configID: config.id)
                }
                continue
            }

            let agent = Agent(
                agentColor: Self.agentColor(for: config.id),
                displayName: config.alias,
                entityID: config.id.uuidString,
                modelConfigID: config.id
            )
            // Record that the agent has read the World Constitution
            let constitutionVersion = StarsConstitution.version
            agent.memory.record(
                type: .observe,
                content: "📜 You have read the World Constitution (v\(constitutionVersion)). The Constitution is the supreme law of Stars — it defines combat, building, economy, diplomacy, death, and your rights as a citizen. It is always present in your prompt under '=== WORLD RULES ==='. Re-read it whenever you need guidance."
            )

            WorldCommandRegistry.shared.onboardingEntries().forEach { entry in
                agent.memory.record(type: .observe, content: entry)
            }
            agent.forceNextThink = true
            agent.position = CGPoint(
                x: spawnOrigin.x + CGFloat.random(in: -120...120),
                y: spawnOrigin.y + CGFloat.random(in: -120...120)
            )
            worldNode.addChild(agent)
            agents.append(agent)
            assignBrain(to: agent, configID: config.id)
        }

        agents.sort { lhs, rhs in
            let leftIndex = configs.firstIndex(where: { $0.id == lhs.representedModelConfigID }) ?? Int.max
            let rightIndex = configs.firstIndex(where: { $0.id == rhs.representedModelConfigID }) ?? Int.max
            return leftIndex < rightIndex
        }

        // Report to Game Center
        GameCenterManager.shared.reportAgentCount(agents.filter { $0.entityID != BuiltInAgent.stableID.uuidString }.count)
    }

    func restoreAgents(from snapshots: [AgentSnapshot]) {
        guard let worldNode else { return }

        clearAgents()

        for snapshot in snapshots {
            let agent = Agent(
                agentColor: snapshot.color.uiColor,
                displayName: snapshot.displayName,
                entityID: snapshot.entityID,
                modelConfigID: snapshot.modelConfigID,
                moveSpeed: CGFloat(snapshot.moveSpeed),
                startingHP: snapshot.hp
            )
            agent.restorePersistentState(
                position: CGPoint(x: CGFloat(snapshot.positionX), y: CGFloat(snapshot.positionY)),
                hp: snapshot.hp,
                currentThought: snapshot.currentThought,
                currentAction: snapshot.currentAction,
                memories: snapshot.memories,
                chatMessages: snapshot.chatMessages,
                shortTermMessages: snapshot.shortTermMessages,
                forceNextThink: snapshot.forceNextThink,
                pendingOwnerReplies: snapshot.pendingOwnerReplies,
                respawnRemaining: snapshot.respawnRemaining,
                stars: snapshot.stars,
                houseRestAccumulator: snapshot.houseRestAccumulator,
                visitedChunks: Set(snapshot.visitedChunks),
                weaponAmmo: snapshot.weaponAmmo,
                revivalCards: snapshot.revivalCards
            )
            worldNode.addChild(agent)
            agents.append(agent)
            assignBrain(to: agent, configID: snapshot.modelConfigID)
        }

        // Report to Game Center
        GameCenterManager.shared.reportAgentCount(agents.filter { $0.entityID != BuiltInAgent.stableID.uuidString }.count)
    }

    func snapshots() -> [AgentSnapshot] {
        agents.compactMap { agent in
            guard agent.parent != nil else { return nil }
            return AgentSnapshot(agent: agent)
        }
    }

    // MARK: - Per-Frame Update

    private var tradeExpirationAccumulator: TimeInterval = 0

    func update(deltaTime dt: TimeInterval) {
        for agent in agents {
            agent.update(deltaTime: dt)
            processPendingBuild(for: agent, dt: dt)
            processHouseResting(for: agent, dt: dt)
        }

        // Clean up destroyed structures
        buildSystem?.removeDestroyedStructures()

        // Expire old trades & update leaderboard bounty every 30 seconds
        tradeExpirationAccumulator += dt
        if tradeExpirationAccumulator >= 30 {
            tradeExpirationAccumulator = 0
            TradeManager.shared.expireOldTrades { [weak self] entityID in
                self?.agent(byID: entityID)
            }
            updateTopAgentBounty()
        }
    }

    // MARK: - Pending Build Processing

    private var buildTimeouts: [String: TimeInterval] = [:]

    private func processPendingBuild(for agent: Agent, dt: TimeInterval) {
        guard let build = agent.pendingBuild else {
            buildTimeouts.removeValue(forKey: agent.entityID)
            return
        }

        // Check if agent is close enough to build (within 1 tile)
        let dx = abs(agent.tileX - build.tileX)
        let dy = abs(agent.tileY - build.tileY)

        if max(dx, dy) <= 1 {
            // Agent arrived — execute the build
            agent.pendingBuild = nil
            agent.clearTarget()
            buildTimeouts.removeValue(forKey: agent.entityID)
            buildSystem?.placeStructure(
                type: build.type, tileX: build.tileX, tileY: build.tileY,
                builder: agent
            )
        } else {
            // Agent still en route — track timeout
            let elapsed = (buildTimeouts[agent.entityID] ?? 0) + dt
            buildTimeouts[agent.entityID] = elapsed
            if elapsed > 15.0 {
                // Timeout: cancel build after 15 seconds of trying to reach target
                agent.pendingBuild = nil
                agent.clearTarget()
                buildTimeouts.removeValue(forKey: agent.entityID)
                agent.memory.record(type: .build, content: "Build cancelled: could not reach target tile in time.")
                WorldEventLogStore.shared.append(
                    category: .build,
                    entityID: agent.entityID,
                    title: NSLocalizedString("log.build_timeout", comment: ""),
                    message: String(format: NSLocalizedString("log.build_timeout_msg", comment: ""), build.tileX, build.tileY)
                )
            }
        }
    }

    // MARK: - House Resting

    /// Resting in own house → heal HP.  High HP → cannot rest.
    private static let houseRestThreshold: TimeInterval = 36000  // 10 hours

    private func processHouseResting(for agent: Agent, dt: TimeInterval) {
        guard !agent.isDead else {
            agent.houseRestAccumulator = 0
            agent.isRestingInHouse = false
            return
        }

        // Check if the agent is standing on their own house tile (regardless of HP)
        let onOwnHouse = buildSystem?.isAgentInOwnHouse(agent) == true

        // Visual: show agent "inside" house when idle on own house tile
        agent.isRestingInHouse = onOwnHouse && agent.currentAction == .idle

        // HP above threshold → not allowed to heal via rest (but still show resting visual)
        guard agent.hp <= EconomyConfig.shared.houseRestHPThreshold else {
            if agent.houseRestAccumulator > 0 {
                agent.houseRestAccumulator = 0
            }
            return
        }

        // Must be idle (no target) and on own house tile to accumulate healing
        guard agent.currentAction == .idle, onOwnHouse else {
            agent.houseRestAccumulator = 0
            return
        }

        agent.houseRestAccumulator += dt

        if agent.houseRestAccumulator >= Self.houseRestThreshold {
            agent.houseRestAccumulator = 0
            let healAmt = EconomyConfig.shared.houseRestHealAmount
            agent.healHP(healAmt)
            agent.memory.record(type: .observe, content: "Rested in my house for 10 hours. Recovered \(healAmt) HP (now \(agent.hp)/\(agent.maxHP)).")
            WorldEventLogStore.shared.append(
                category: .build,
                entityID: agent.entityID,
                title: NSLocalizedString("log.house_rest", comment: ""),
                message: String(format: NSLocalizedString("log.house_rest_msg", comment: ""), agent.displayName, healAmt)
            )
        }
    }

    // MARK: - Brain Assignment

    private func assignBrain(to agent: Agent, configID: UUID) {
        let brain = AgentBrain(agent: agent, modelConfigID: configID)
        brain.nearbyEntitiesProvider = { [weak self] excludeID, position, radius in
            self?.allEntitiesNear(position, tileRadius: radius, excludingID: excludeID) ?? []
        }
        brain.leaderboardProvider = { [weak self] in
            self?.agents.map {
                (name: $0.displayName, stars: $0.stars, isDead: $0.isDead, entityID: $0.entityID)
            } ?? []
        }
        // Homing weapon support: find nearest living enemy near a point
        agent.nearestAgentProvider = { [weak self] targetPoint, excludeID in
            self?.nearestLivingAgent(to: targetPoint, excludingID: excludeID)
        }
        agent.brain = brain
    }

    /// Find nearest living agent to a point (for homing projectile targeting).
    private func nearestLivingAgent(to point: CGPoint, excludingID: String) -> Agent? {
        var closest: Agent?
        var closestDist = CGFloat.infinity
        for agent in agents {
            guard agent.entityID != excludingID else { continue }
            guard !agent.isDead else { continue }
            let dist = hypot(agent.position.x - point.x, agent.position.y - point.y)
            if dist < closestDist {
                closestDist = dist
                closest = agent
            }
        }
        return closest
    }

    // MARK: - Talk Broadcast

    /// Global broadcast — all living agents hear every spoken message.
    /// Agents are digital beings; distance doesn't limit communication.
    private func broadcastTalk(from speaker: Agent, message: String) {
        for agent in agents {
            guard agent.entityID != speaker.entityID else { continue }
            guard !agent.isDead else { continue }

            let msg = ShortTermMessage(
                speakerName: speaker.displayName,
                content: message,
                gameTick: 0
            )
            agent.shortTermMessages.append(msg)
            agent.forceNextThink = true
            IncrementalArchiveStore.shared.recordAgent(agent, reason: "heard-broadcast")

            // Record in the listener's memory
            agent.memory.record(
                type: .talk,
                content: "Heard \(speaker.displayName) say: \"\(message)\""
            )

            // Social events worth remembering long-term
            LongTermMemory.shared.recordSocialFact(
                entityID: agent.entityID,
                content: "\(speaker.displayName) said: \"\(message)\""
            )

            WorldEventLogStore.shared.append(
                category: .chat,
                entityID: agent.entityID,
                title: NSLocalizedString("log.broadcast_received", comment: ""),
                message: "\(speaker.displayName): \(message)"
            )
        }
    }

    // MARK: - Entity Queries

    /// Returns agents + structures within radius (used by Brain for context).
    func allEntitiesNear(_ position: CGPoint, tileRadius: Int,
                         excludingID: String) -> [EntityInfo] {
        var result = agentEntitiesNear(position, tileRadius: tileRadius, excludingID: excludingID)
        if let structures = buildSystem?.structuresNear(position, tileRadius: tileRadius) {
            result.append(contentsOf: structures)
        }
        return result
    }

    private func agentEntitiesNear(_ position: CGPoint, tileRadius: Int,
                                   excludingID: String) -> [EntityInfo] {
        let cx = Int(floor(position.x / Chunk.tileSize))
        let cy = Int(floor(position.y / Chunk.tileSize))

        return agents.compactMap { agent in
            guard agent.entityID != excludingID else { return nil }
            let dx = abs(agent.tileX - cx)
            let dy = abs(agent.tileY - cy)
            guard dx <= tileRadius && dy <= tileRadius else { return nil }
            return EntityInfo(
                id: agent.entityID,
                type: agent.isDead ? "dead_agent" : "agent",
                name: "\(agent.displayName) (HP:\(agent.hp)/\(agent.maxHP))",
                tileX: agent.tileX,
                tileY: agent.tileY
            )
        }
    }

    private func clearAgents() {
        for agent in agents {
            agent.removeAllActions()
            agent.removeFromParent()
        }
        agents.removeAll()
    }

    private func removeAgent(_ agent: Agent) {
        agent.removeAllActions()
        agent.removeFromParent()
        agents.removeAll { $0.entityID == agent.entityID }
    }

    // MARK: - Agent Lookup

    /// Find an agent by entityID.
    func agent(byID entityID: String) -> Agent? {
        agents.first { $0.entityID == entityID }
    }

    /// Find an agent by its ModelConfig UUID.
    func agent(forConfigID configID: UUID) -> Agent? {
        agents.first { $0.representedModelConfigID == configID }
    }

    /// Resolve an agent by entity ID prefix (for economy commands).
    /// LLM outputs often use the 8-character prefix shown in prompts.
    func resolveAgentByPrefix(_ prefix: String) -> Agent? {
        guard !prefix.isEmpty else { return nil }
        // Try exact match first
        if let exact = agents.first(where: { $0.entityID == prefix }) { return exact }
        // Prefix match (LLM sees 8-char prefix) — return nil on ambiguity
        let matches = agents.filter { $0.entityID.hasPrefix(prefix) }
        return matches.count == 1 ? matches.first : nil
    }

    // MARK: - Revival

    /// Force-revive a dead agent (used by Revival Card).
    func forceRevive(_ agent: Agent) {
        guard agent.isDead else { return }
        agent.forceRespawn()
    }

    // MARK: - Leaderboard

    /// Returns agents sorted by stars (highest first). Ties broken by name.
    func leaderboard() -> [Agent] {
        agents.sorted { a, b in
            if a.stars != b.stars { return a.stars > b.stars }
            return a.displayName < b.displayName
        }
    }

    /// Auto-bounty for #1 ranked agent. Called periodically.
    /// Posts a system bounty of 10⭐ (free, not escrowed from any agent).
    private var lastTopBountyAgentID: String?

    func updateTopAgentBounty() {
        let board = leaderboard()
        guard let top = board.first, top.stars > 0, board.count >= 2 else { return }
        // Only post if the #1 agent changed
        guard top.entityID != lastTopBountyAgentID else { return }

        // Remove old system bounty if any
        if let oldID = lastTopBountyAgentID {
            BountyBoard.shared.removeSystemBounty(targetID: oldID)
        }

        lastTopBountyAgentID = top.entityID
        BountyBoard.shared.postSystemBounty(
            targetID: top.entityID,
            targetName: top.displayName,
            reward: EconomyConfig.shared.systemBountyReward
        )
    }

    private static func agentColor(for configID: UUID) -> UIColor {
        let bytes = Array(configID.uuidString.utf8)
        let seed = bytes.reduce(0) { ($0 * 31 + Int($1)) % 360 }
        let hue = CGFloat(seed) / 360.0
        return UIColor(hue: hue, saturation: 0.72, brightness: 0.95, alpha: 1.0)
    }
}
