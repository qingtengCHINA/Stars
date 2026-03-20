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

    // Death control — when stopped, no API calls are made
    private(set) var isStopped = false

    /// Closure provided by AgentManager:
    ///   (excludeID, worldPosition, tileRadius) → [EntityInfo]
    var nearbyEntitiesProvider: ((String, CGPoint, Int) -> [EntityInfo])?

    // MARK: - Init

    init(agent: Agent, modelConfigID: UUID? = nil) {
        self.agent = agent
        self.modelConfigID = modelConfigID
        tickAccumulator = TimeInterval.random(in: 0..<tickInterval)
    }

    // MARK: - Stop / Resume (Death System)

    /// Stop the brain — called when agent dies. No more API calls.
    func stop() {
        isStopped = true
        isThinking = false
        hasQueuedThink = false
        tickAccumulator = 0
    }

    /// Resume the brain — called when agent respawns.
    func resume() {
        isStopped = false
        tickAccumulator = 0
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

        guard LLMService.shared.reserveSlot() else { return }

        thinkCount += 1
        let prompt = buildContextPrompt(using: config)
        hasQueuedThink = false
        tickAccumulator = 0
        isThinking = true

        Task { [weak self, weak agent] in
            defer {
                LLMService.shared.releaseSlot()
                self?.isThinking = false
                self?.drainQueuedThinkIfNeeded()
            }

            do {
                let (response, rawResponseText) = try await LLMService.shared.sendPromptWithRaw(prompt, using: config)
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
                }
            } catch {
                if let agent, agent.pendingOwnerReplies > 0 {
                    let message = "模型调用失败：\(error.localizedDescription)"
                    agent.recordSystemMessage(message, consumesOwnerReply: true)
                    agent.memory.record(type: .talk, content: message)
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
        let shouldReflect = thinkCount % 10 == 0
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
        {"thought":"inner monologue","command":"/move","action":"idle|move|build|attack|talk","speech":"what you say out loud","target":{"x":0,"y":0,"buildType":"wall","weapon":"melee"},"customCommand":null,"soulReflection":null}

        Rules:
        - command should be one of the world commands or a previously learned custom alias
        - action: idle, move, build, attack, talk
        - speech is required when action is talk, otherwise it may be null
        - target.x / target.y: integer tile coordinates
        - build: set target.buildType to "wall" or "trap"
        - attack: set target.weapon to "melee" or "ranged"
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
                LongTermMemory.shared.distill(
                    entityID: agent.entityID,
                    compactedSummary: result.summary
                )
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

        // Flush long-term memory saves periodically
        if thinkCount % 5 == 0 {
            LongTermMemory.shared.flushPendingSaves()
        }

        agent.shortTermMessages.removeAll()
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

        lines.append("""
        Equipment:
        - Melee weapon: 15 damage, range 1 tile, cooldown 0.8s
        - Ranged weapon: 10 damage, range 5 tiles, cooldown 1.2s
        - You can build walls (HP:100, blocks movement) or traps (HP:30, deals 25 damage on contact)
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
                lines.append("  - \(entity.name) [\(entity.type)] at (\(entity.tileX), \(entity.tileY)) — \(proximity) (dist \(dist))")
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

        // SOUL (per-agent personality)
        let soul = SoulStore.shared.soul(for: agent.entityID)
        lines.append("")
        lines.append(soul.promptSection)

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
        think()
    }
}
