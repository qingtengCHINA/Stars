//
//  AgentBrain.swift
//  Stars
//
//  Each Agent owns one Brain.  On every tick the Brain:
//    1. collects ALL entities in the world (agents are digital beings)
//    2. builds a context prompt with HP, weapons, surroundings, memories
//    3. sends it to the assigned LLM asynchronously
//    4. feeds the parsed response back into the Agent via ActionResolver
//
//  Death stops the brain — no token consumption while dead.
//

import SpriteKit

/// Drives a single Agent's decision-making loop via LLM calls.
/// Must run on MainActor — think() creates Tasks that suspend for
/// network I/O but resume on MainActor for SpriteKit state mutation.
@MainActor
final class AgentBrain {

    weak var agent: Agent?
    var modelConfigID: UUID?

    // Tick timing
    private var tickAccumulator: TimeInterval = 0
    var tickInterval: TimeInterval = 5.0

    // Prevents overlapping requests for the same agent
    private(set) var isThinking = false
    private var hasQueuedThink = false
    private var thinkCount = 0
    private var thinkTask: Task<Void, Never>?

    // Death control — when stopped, no API calls are made
    private(set) var isStopped = false

    // Consecutive API failure counter — drives fallback behavior & backoff
    private var consecutiveFailures = 0

    // MARK: - Adaptive SOUL Reflection Tracking

    /// Counter of significant events since last SOUL reflection.
    /// When this reaches the threshold, reflection becomes REQUIRED.
    private var significantEventsSinceReflection = 0
    private let significantEventThreshold = 3

    /// Notify the brain that a significant event occurred (kill, death,
    /// alliance, compaction, etc.). Accumulates toward forced reflection.
    func recordSignificantEvent() {
        significantEventsSinceReflection += 1
    }

    /// Closure provided by AgentManager:
    ///   (excludeID, worldPosition, tileRadius) → [EntityInfo]
    var nearbyEntitiesProvider: ((String, CGPoint, Int) -> [EntityInfo])?

    /// Closure provided by AgentManager: returns leaderboard entries (name, stars, isDead, entityID).
    var leaderboardProvider: (() -> [(name: String, stars: Int, isDead: Bool, entityID: String)])?

    // MARK: - Init

    init(agent: Agent, modelConfigID: UUID? = nil) {
        self.agent = agent
        self.modelConfigID = modelConfigID
        tickAccumulator = TimeInterval.random(in: 0..<tickInterval)
    }

    // MARK: - Stop / Resume (Death System)

    /// Stop the brain — called when agent dies. No more API calls.
    /// The in-flight Task (if any) is cancelled; its `defer` block owns
    /// the `isThinking` flag and slot release — we never force-clear them.
    func stop() {
        isStopped = true
        thinkTask?.cancel()
        thinkTask = nil
        hasQueuedThink = false
        tickAccumulator = 0
    }

    /// Resume the brain — called when agent respawns.
    func resume() {
        isStopped = false
        tickAccumulator = 0
        thinkCount = 0
    }

    // MARK: - Tick

    func update(deltaTime dt: TimeInterval) {
        guard !isStopped else { return }  // Dead agents don't think

        // Force-think when the agent received a dialogue broadcast
        if let agent, agent.forceNextThink {
            agent.forceNextThink = false
            hasQueuedThink = true
        }

        tickAccumulator += dt
        if tickAccumulator >= tickInterval {
            hasQueuedThink = true
        }

        guard !isThinking else { return }
        guard hasQueuedThink else { return }
        think()
    }

    func requestImmediateThink() {
        guard !isStopped else { return }
        hasQueuedThink = true
        guard !isThinking else { return }
        think()
    }

    // MARK: - Think Cycle

    private func think() {
        guard !isStopped else { return }
        guard let agent,
              let configID = modelConfigID,
              let config = ModelManager.shared.config(for: configID)
        else { return }

        // Subscription-gated: pause agents that exceed tier limits
        if SubscriptionStore.shared.isAgentPaused(config: config) {
            hasQueuedThink = false
            tickAccumulator = 0

            // If the user sent a message, give feedback instead of silent "正在思考..."
            if agent.pendingOwnerReplies > 0 {
                let tierName = config.provider.requiredSubscriptionTier.displayName
                let msg = String(
                    format: NSLocalizedString("chat.agent_paused", comment: ""),
                    tierName
                )
                agent.recordSystemMessage(msg, consumesOwnerReply: true)
            }
            return
        }

        // Priority: agents with pending owner replies get extra slots
        let hasPendingReply = agent.pendingOwnerReplies > 0
        if hasPendingReply {
            guard LLMService.shared.reservePrioritySlot() else {
                #if DEBUG
                print("[Brain] ⏳ \(agent.displayName) waiting for priority slot (active: \(LLMService.shared.activeRequests))")
                #endif
                return
            }
        } else {
            guard LLMService.shared.reserveSlot() else { return }
        }

        thinkCount += 1
        let prompt = buildContextPrompt(using: config)
        hasQueuedThink = false
        tickAccumulator = 0
        isThinking = true

        thinkTask = Task { [weak self, weak agent] in
            defer {
                LLMService.shared.releaseSlot()
                self?.isThinking = false
                self?.thinkTask = nil
                self?.drainQueuedThinkIfNeeded()
            }

            guard !Task.isCancelled else { return }

            do {
                // Only retry parse failures when the player is waiting for a reply.
                // Autonomous thinks skip retry to free up slots faster.
                let (response, rawResponseText) = try await LLMService.shared.sendPromptWithRaw(prompt, using: config, allowRetry: hasPendingReply)
                self?.consecutiveFailures = 0
                self?.tickInterval = 5.0  // restore normal rate on success
                if let agent {
                    // Track response tokens
                    let responseTokens = ContextBudgetMonitor.estimateTokens(for: rawResponseText)
                    if var usage = agent.latestContextUsage {
                        usage = ContextUsageSnapshot(
                            usedTokens: usage.usedTokens,
                            limitTokens: usage.limitTokens,
                            didCompact: usage.didCompact,
                            compactedMemoryEntries: usage.compactedMemoryEntries,
                            compactedChatMessages: usage.compactedChatMessages,
                            responseTokens: responseTokens
                        )
                        agent.updateContextUsage(usage)
                    }
                    ActionResolver.execute(response, on: agent)
                    // Clear messages only after a successful response —
                    // if the request fails, messages are preserved for the next attempt.
                    agent.shortTermMessages.removeAll()
                }
            } catch {
                if let agent {
                    self?.consecutiveFailures += 1
                    let failCount = self?.consecutiveFailures ?? 1

                    if agent.pendingOwnerReplies > 0 {
                        let message = "模型调用失败：\(error.localizedDescription)"
                        agent.recordSystemMessage(message, consumesOwnerReply: true)
                    }

                    // Fallback behavior: after failures, agent does something instead of freezing
                    if failCount >= 2 {
                        // After 2+ failures, give the agent a random idle/explore action
                        agent.currentAction = .idle
                        agent.currentThought = "⚠️ Model unreachable — waiting..."
                        agent.memory.record(type: .observe, content: "Model call failed (\(failCount)x): \(error.localizedDescription)")

                        // Slow down think rate to avoid hammering a failing API
                        self?.tickInterval = min(15.0, 5.0 + Double(failCount) * 2.0)
                    }
                }
                print("[Brain] \(agent?.displayName ?? "?") error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Context Prompt Builder

    private func buildContextPrompt(using config: ModelConfig) -> String {
        guard let agent else { return "" }

        let tx = agent.tileX
        let ty = agent.tileY

        // World-wide awareness — agents are digital beings, they see everything
        let allEntities = nearbyEntitiesProvider?(agent.entityID, agent.position, 99999) ?? []
        let commandSection = WorldCommandRegistry.shared.promptSection()

        // Adaptive SOUL reflection: triggered by significant events OR periodic fallback (every 6 thinks)
        let shouldReflect = significantEventsSinceReflection >= significantEventThreshold
            || thinkCount % 6 == 0
        if shouldReflect {
            significantEventsSinceReflection = 0  // reset counter
        }
        let soulReflectionClause = shouldReflect
            ? """
            - soulReflection: REQUIRED this turn. Reflect on your recent experiences and update your SOUL:
              {"personality":"who I am","beliefs":"what I believe","goals":"what I want to achieve","journal":"short summary of recent events and lessons learned"}
            """
            : """
            - soulReflection is optional; include it only when you feel a significant shift in personality, beliefs, or goals
            """

        let responseSection = """
        Decide your next action. Respond with a single JSON object ONLY:
        {"thought":"inner monologue","command":"/move","action":"idle|move|build|attack|talk","speech":"what you say out loud","target":{"x":0,"y":0,"buildType":"wall","weapon":"melee","starsAmount":0,"recipientID":""},"customCommand":null,"soulReflection":null}

        Rules:
        - command should be one of the world commands or a previously learned custom alias
        - action: idle, move, build, attack, talk
        - speech is required when action is talk, otherwise it may be null
        - target.x / target.y: integer tile coordinates
        - build: set target.buildType to "wall", "trap", or "house". Costs: wall=\(EconomyConfig.shared.wallCost)⭐, trap=\(EconomyConfig.shared.trapCost)⭐, house=\(EconomyConfig.shared.houseCost)⭐
        - attack: set target.weapon to "melee" or "ranged"
        - economy: set target.recipientID (entity ID prefix) and target.starsAmount for /pay, /offer_trade, /bounty, /hire, /accept_trade, /decline_trade, /cancel_bounty
        - idle / talk: target may be null
        - customCommand is optional; only use it when creating a safe alias to an existing command
        \(soulReflectionClause)
        - Do NOT include any text outside the JSON
        """

        var pendingMessages = agent.shortTermMessages
        var memories = agent.memory.recentEntries(count: 15)
        var chatMessages = Array(agent.chatMessages.suffix(12))

        // Build a context string for keyword-based memory recall
        let situationContext = buildSituationContext(agent: agent, entities: allEntities, pendingMessages: pendingMessages)

        var prompt = composePrompt(
            agent: agent,
            tx: tx,
            ty: ty,
            entities: allEntities,
            memories: memories,
            chatMessages: chatMessages,
            pendingMessages: pendingMessages,
            situationContext: situationContext,
            commandSection: commandSection,
            responseSection: responseSection
        )

        let limit = max(config.provider.definition.contextWindowTokens - 2048, 8_192)
        var compactedMemoryEntries = 0
        var compactedChatMessages = 0
        var didCompact = false

        if ContextBudgetMonitor.estimateTokens(for: prompt) > Int(Double(limit) * 0.78) {
            if let result = agent.memory.compactOlderEntries(keepingRecent: 8) {
                compactedMemoryEntries = result.compactedEntryCount
                memories = agent.memory.recentEntries(count: 10)
                didCompact = true

                // Structured distillation — extract categorized knowledge entries
                if !result.extracts.isEmpty {
                    LongTermMemory.shared.distillFromCompaction(
                        entityID: agent.entityID,
                        extracts: result.extracts
                    )
                } else {
                    // Fallback to legacy distillation if no extracts
                    LongTermMemory.shared.distill(
                        entityID: agent.entityID,
                        compactedSummary: result.summary
                    )
                }

                // Auto-read constitution reminder after compaction
                // (See Constitution § XII — agents must re-read rules after compaction)
                agent.memory.record(
                    type: .observe,
                    content: "⚠️ Context compacted. Re-read the WORLD RULES (Constitution) in your prompt. Check: weapon inventory, economy commands, house defense, leaderboard, and your relationships/plans."
                )

                // Compaction is a significant event → trigger SOUL reflection soon
                recordSignificantEvent()
            }

            if ContextBudgetMonitor.estimateTokens(for: prompt) > Int(Double(limit) * 0.82) {
                compactedChatMessages = agent.compactChatHistory(keepingRecent: 8)
                chatMessages = Array(agent.chatMessages.suffix(8))
                didCompact = didCompact || compactedChatMessages > 0
            }

            if pendingMessages.count > 6 {
                pendingMessages = Array(pendingMessages.suffix(6))
            }

            prompt = composePrompt(
                agent: agent,
                tx: tx,
                ty: ty,
                entities: allEntities,
                memories: memories,
                chatMessages: chatMessages,
                pendingMessages: pendingMessages,
                situationContext: situationContext,
                commandSection: commandSection,
                responseSection: responseSection
            )
        }

        let usage = ContextUsageSnapshot(
            usedTokens: ContextBudgetMonitor.estimateTokens(for: prompt),
            limitTokens: limit,
            didCompact: didCompact,
            compactedMemoryEntries: compactedMemoryEntries,
            compactedChatMessages: compactedChatMessages
        )
        agent.updateContextUsage(usage)
        if didCompact {
            IncrementalArchiveStore.shared.recordAgent(agent, reason: "context-compact")
            WorldEventLogStore.shared.append(
                category: .context,
                entityID: agent.entityID,
                title: "自动 Compact",
                message: "上下文占用 \(usage.percentageText)，已压缩 \(compactedMemoryEntries) 条记忆和 \(compactedChatMessages) 条旧对话。"
            )
        }

        // Periodic memory maintenance
        if thinkCount % 5 == 0 {
            LongTermMemory.shared.flushPendingSaves()
        }
        // Priority-based decay: evict stale low-importance entries (every 20 thinks ≈ 100s)
        if thinkCount % 20 == 0 {
            LongTermMemory.shared.decayStaleEntries(for: agent.entityID)
        }

        // Note: shortTermMessages are cleared by the caller (think())
        // AFTER the LLM response succeeds, to avoid losing messages if the
        // request fails or the agent dies mid-flight.
        return prompt
    }

    /// Build a short context string describing the current situation (for keyword memory search).
    private func buildSituationContext(agent: Agent, entities: [EntityInfo], pendingMessages: [ShortTermMessage]) -> String {
        var parts = [String]()
        for entity in entities.prefix(5) {
            parts.append(entity.name)
        }
        for msg in pendingMessages {
            parts.append("\(msg.speakerName) \(msg.content)")
        }
        if let thought = agent.currentThought {
            parts.append(thought)
        }
        return parts.joined(separator: " ")
    }

    private func composePrompt(
        agent: Agent,
        tx: Int,
        ty: Int,
        entities: [EntityInfo],
        memories: [MemoryEntry],
        chatMessages: [ChatMessageEntry],
        pendingMessages: [ShortTermMessage],
        situationContext: String,
        commandSection: String,
        responseSection: String
    ) -> String {
        var lines = [String]()

        lines.append("""
        You are "\(agent.displayName)" (HP: \(agent.hp)/\(agent.maxHP)), \
        an AI agent in a 2D pixel sandbox world called Stars.
        Your current tile position is (\(tx), \(ty)).
        \(WorldClock.shared.promptContext)
        """)

        let ownerPrefix = String(agent.entityID.prefix(8))

        let nearDeathWarning = agent.isNearDeath
            ? "\n⚠️ NEAR-DEATH: HP ≤ 5! Your speed is halved. Retreat, rest, or seek help immediately!"
            : ""
        let nightWarning = WorldClock.shared.isNight
            ? "\n🌙 Night time: all agents move 30% slower. Stealth and defense are favored."
            : ""

        lines.append("""
        Your entity ID prefix: \(ownerPrefix) (structures you own show "owner:\(ownerPrefix)")
        You can build: walls (2⭐, HP:100), traps (3⭐, HP:30, deals 25 damage), houses (5⭐, HP:150)
        Stars: \(agent.stars)⭐ | Explored chunks: \(agent.visitedChunks.count) | Revival Cards: \(agent.revivalCards)\(nearDeathWarning)\(nightWarning)
        Rules:
        - Killing another agent earns 1⭐. Discovering a new area earns 1⭐.
        - Stars are CURRENCY: spend to build, trade, hire, post bounties, buy weapons, buy revival cards.
        - Economy commands: /pay, /offer_trade, /accept_trade, /decline_trade, /bounty, /cancel_bounty, /hire, /buy_weapon, /buy_revival, /revive.
          All economy commands use target.recipientID (entity ID prefix) and target.starsAmount.
        - /buy_weapon: say weapon ID in speech to buy. /buy_revival: buy revival card (150⭐). /revive: use a card to revive a dead agent.
        - When attacking, set target.weapon to the weapon ID (e.g. "sword", "rifle", "rocket_launcher"). Use melee/ranged as fallback.
        - Resting in your own house for 10 hours heals 5 HP (only when HP ≤ 50).
        - Agents with HP > 50 cannot rest in houses.
        - To rest in your house: use /rest or /enter_house (system auto-navigates), or MOVE to its tile coordinates then idle. Healing begins automatically.
        - When HP ≤ 5: near-death state — speed halved, pulsing red. Consider /flee, /rest, or /retreat.
        - During night (19:00–05:00): all movement is 30% slower. Plan accordingly.
        - Traps are invisible until triggered. After triggering, the victim learns the trap's location.
        """)

        // World-wide entity awareness — tiered by distance
        if entities.isEmpty {
            lines.append("World: you are alone. No other agents or structures detected.")
        } else {
            lines.append("All known entities in the world:")
            for entity in entities {
                let dist = max(abs(entity.tileX - tx), abs(entity.tileY - ty))
                let proximity: String
                if dist <= 5        { proximity = "very close" }
                else if dist <= 20  { proximity = "nearby" }
                else if dist <= 50  { proximity = "moderate distance" }
                else                { proximity = "far away" }
                let ownTag = entity.name.contains("owner:\(ownerPrefix)") ? " ← YOURS" : ""
                lines.append("  - \(entity.name) [\(entity.type)] at (\(entity.tileX), \(entity.tileY)) — \(proximity) (dist \(dist))\(ownTag)")
            }
        }

        if !chatMessages.isEmpty {
            lines.append("Recent direct conversation:")
            for message in chatMessages {
                let role: String
                switch message.speaker {
                case .owner: role = "主人"
                case .agent: role = agent.displayName
                case .system: role = "系统"
                }
                lines.append("  - \(role): \(message.text)")
            }
        }

        if !memories.isEmpty {
            lines.append("Your recent memories (short-term):")
            for memory in memories {
                lines.append("  - [\(memory.type.rawValue)] \(memory.content)")
            }
        }

        // Long-term knowledge — importance-based (always present)
        let knowledgeSection = LongTermMemory.shared.promptSection(for: agent.entityID)
        if !knowledgeSection.isEmpty {
            lines.append("")
            lines.append(knowledgeSection)
        }

        // Contextual recall — keyword-relevant memories triggered by current situation
        let contextualSection = LongTermMemory.shared.contextualSection(for: agent.entityID, context: situationContext)
        if !contextualSection.isEmpty {
            lines.append("")
            lines.append(contextualSection)
        }

        // Weapon inventory — what this agent already owns
        let weaponInventory = WeaponCatalog.inventoryPromptSection(ownedWeapons: agent.ownedWeapons, weaponAmmo: agent.weaponAmmo)
        if !weaponInventory.isEmpty {
            lines.append("")
            lines.append(weaponInventory)
        }

        // Weapon shop — what's available to buy (only shows weapons not yet owned)
        let weaponShop = WeaponCatalog.shopPromptSection(ownedWeapons: agent.ownedWeapons, currentStars: agent.stars)
        lines.append("")
        lines.append(weaponShop)

        // Economy: pending trades for this agent
        let tradeSection = TradeManager.shared.promptSection(for: agent.entityID)
        if !tradeSection.isEmpty {
            lines.append("")
            lines.append(tradeSection)
        }

        // Economy: global bounty board
        let bountySection = BountyBoard.shared.promptSection()
        if !bountySection.isEmpty {
            lines.append("")
            lines.append(bountySection)
        }

        // Leaderboard — agents ranked by stars (sorted highest → lowest)
        if let rawRankings = leaderboardProvider?(), !rawRankings.isEmpty {
            let rankings = rawRankings.sorted { $0.stars > $1.stars }
            lines.append("")
            lines.append("⭐ Leaderboard / 排行榜 (ranked by Stars, highest first):")
            for (idx, entry) in rankings.enumerated() {
                let rank = idx + 1
                let marker = entry.entityID.hasPrefix(agent.entityID.prefix(8).description) ? " ← YOU" : ""
                let dead = entry.isDead ? " 💀" : ""
                let bounty = (rank == 1 && rankings.count >= 2 && entry.stars > 0) ? " 🎯BOUNTY(+\(EconomyConfig.shared.systemBountyReward)⭐)" : ""
                lines.append("  #\(rank) \(entry.name): \(entry.stars)⭐\(dead)\(bounty)\(marker)")
            }
        }

        if !pendingMessages.isEmpty {
            lines.append("Messages you just received:")
            for message in pendingMessages {
                lines.append("  - \(message.speakerName) said: \"\(message.content)\"")
            }
            lines.append("You may respond, ignore, or react in any way you choose.")
            if pendingMessages.contains(where: { $0.speakerName == "主人" }) {
                lines.append("Messages from 主人 are direct player commands and should be prioritized unless impossible or unsafe.")
                lines.append("If the latest message is from 主人, include a direct speech reply for the owner even when your chosen action is move/build/attack.")
            }
        }

        if let prev = agent.currentThought {
            lines.append("Your previous thought: \"\(prev)\"")
        }

        // AGENTS file (world rules / constitution)
        let agentsSection = AgentsFile.shared.promptSection
        if !agentsSection.isEmpty {
            lines.append("")
            lines.append(agentsSection)
        }

        // Player-editable command rules
        let commandsRulesSection = CommandsFile.shared.promptSection
        if !commandsRulesSection.isEmpty {
            lines.append("")
            lines.append(commandsRulesSection)
        }

        // Player-editable economy rules
        let economyRulesSection = EconomyFile.shared.promptSection
        if !economyRulesSection.isEmpty {
            lines.append("")
            lines.append(economyRulesSection)
        }

        // SOUL (per-agent personality)
        let soul = SoulStore.shared.soul(for: agent.entityID)
        lines.append("")
        lines.append(soul.promptSection)

        // Built-in agent (星尘) has system knowledge to answer player questions
        if agent.entityID == BuiltInAgent.stableID.uuidString {
            lines.append("")
            lines.append(BuiltInAgent.systemKnowledge)
            lines.append("You are 星尘 (Stardust), the built-in guide of Stars. When the Owner asks about the game system, commands, or mechanics, use your system knowledge to give helpful answers. You are also a regular agent — you live, fight, build, and explore like everyone else.")
        }

        lines.append("")
        lines.append(commandSection)
        lines.append("")
        lines.append(responseSection)
        return lines.joined(separator: "\n")
    }

    private func drainQueuedThinkIfNeeded() {
        guard !isStopped else { return }
        guard hasQueuedThink else { return }
        guard !isThinking else { return }

        // Only drain immediately when the player is waiting for a reply.
        // Otherwise, yield the slot to let other agents think fairly.
        // The regular update() tick will re-trigger this agent next cycle.
        if let agent, agent.pendingOwnerReplies > 0 {
            think()
        }
    }
}
