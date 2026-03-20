//
//  ActionResolver.swift
//  Stars
//
//  1. parse()   — extract a structured LLMResponse from raw LLM text
//  2. execute() — translate the response into concrete Agent mutations
//

import Foundation

/// Parses LLM JSON responses and applies them to Agent state.
/// Must run on MainActor — mutates SpriteKit nodes directly.
@MainActor
final class ActionResolver {

    // MARK: - JSON Parsing

    /// Parse raw LLM output into an LLMResponse.
    /// Handles markdown code fences, leading/trailing prose, and whitespace.
    static func parse(_ rawText: String) throws -> LLMResponse {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip ```json ... ``` or ``` ... ``` code fences
        if text.contains("```") {
            var jsonLines = [String]()
            var inside = false
            for line in text.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("```") {
                    inside.toggle()
                    continue
                }
                if inside { jsonLines.append(line) }
            }
            if !jsonLines.isEmpty {
                text = jsonLines.joined(separator: "\n")
            }
        }

        // Locate the outermost { ... }
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}")
        else {
            throw LLMError.parseFailed("No JSON object found")
        }
        let jsonString = String(text[start...end])

        guard let data = jsonString.data(using: .utf8) else {
            throw LLMError.parseFailed("Invalid UTF-8")
        }

        do {
            return try JSONDecoder().decode(LLMResponse.self, from: data)
        } catch {
            // Try repairing truncated JSON before giving up
            let repaired = ProviderPayloadCodec.repairTruncatedJSON(jsonString)
            if repaired != jsonString, let repairedData = repaired.data(using: .utf8) {
                if let response = try? JSONDecoder().decode(LLMResponse.self, from: repairedData) {
                    return response
                }
            }
            throw LLMError.parseFailed(error.localizedDescription)
        }
    }

    // MARK: - Broadcast Callback

    /// Set by AgentManager to broadcast talk messages to nearby agents.
    static var talkBroadcast: ((Agent, String) -> Void)?

    // MARK: - Action Execution

    /// Apply an LLMResponse to the given agent.
    static func execute(_ response: LLMResponse, on agent: Agent) {
        let commandRegistry = WorldCommandRegistry.shared
        if let customCommand = response.customCommand,
           commandRegistry.registerAliasIfSafe(customCommand) {
            agent.memory.record(
                type: .observe,
                content: "Learned custom command \(customCommand.name) based on \(customCommand.basedOn)."
            )
        }

        let resolvedCommand = commandRegistry.resolve(
            commandName: response.command,
            fallbackAction: response.action
        )

        agent.currentThought = response.thought
        agent.currentAction = resolvedCommand.action
        let trimmedSpeech = response.speech?.trimmingCharacters(in: .whitespacesAndNewlines)
        let replyText = (trimmedSpeech?.isEmpty == false)
            ? trimmedSpeech
            : (agent.pendingOwnerReplies > 0 ? response.thought.trimmingCharacters(in: .whitespacesAndNewlines) : nil)

        switch resolvedCommand.action {
        case .idle:
            agent.clearTarget()
            if let replyText, !replyText.isEmpty {
                agent.showSpeechBubble(replyText)
                agent.recordAgentReply(replyText)
            }
            agent.memory.record(
                type: .observe,
                content: "Decided to idle with command \(resolvedCommand.name). Thought: \(response.thought)"
            )

        case .move:
            if let t = response.target, let x = t.x, let y = t.y {
                agent.moveTo(tileX: x, tileY: y)
                if let replyText, !replyText.isEmpty {
                    agent.showSpeechBubble(replyText)
                    agent.recordAgentReply(replyText)
                }
                agent.memory.record(
                    type: .move,
                    content: "Executing \(resolvedCommand.name) toward (\(x), \(y)). Thought: \(response.thought)"
                )
            } else {
                agent.clearTarget()
            }

        case .talk:
            let spokenText = (replyText?.isEmpty == false) ? replyText! : response.thought
            agent.showSpeechBubble(spokenText)
            agent.recordAgentReply(spokenText)
            agent.clearTarget()
            agent.memory.record(type: .talk, content: "Said with \(resolvedCommand.name): \"\(spokenText)\"")
            talkBroadcast?(agent, spokenText)

        case .build:
            if let t = response.target, let x = t.x, let y = t.y {
                let buildTypeName = t.buildType ?? resolvedCommand.defaultBuildType ?? "wall"
                let bType: StructureType = (buildTypeName == "trap") ? .trap : .wall
                agent.pendingBuild = PendingBuild(type: bType, tileX: x, tileY: y)
                // Move toward build target — build executes when agent arrives within 1 tile
                agent.moveTo(tileX: x, tileY: y)
                if let replyText, !replyText.isEmpty {
                    agent.showSpeechBubble(replyText)
                    agent.recordAgentReply(replyText)
                }
                agent.memory.record(
                    type: .build,
                    content: "Executing \(resolvedCommand.name): moving to build a \(bType.rawValue) at (\(x), \(y))"
                )
            } else {
                agent.clearTarget()
            }

        case .attack:
            let weaponName = response.target?.weapon ?? resolvedCommand.defaultWeapon ?? "melee"
            agent.pendingWeapon = WeaponType(rawValue: weaponName) ?? .melee
            if let t = response.target, let x = t.x, let y = t.y {
                agent.moveTo(tileX: x, tileY: y)
                if let replyText, !replyText.isEmpty {
                    agent.showSpeechBubble(replyText)
                    agent.recordAgentReply(replyText)
                }
                agent.memory.record(
                    type: .combat,
                    content: "Executing \(resolvedCommand.name): attacking (\(x), \(y)) with \(agent.pendingWeapon.rawValue)"
                )
            }
        }

        // Soul reflection — agent updates its own personality/beliefs/goals
        if let reflection = response.soulReflection {
            var soul = SoulStore.shared.soul(for: agent.entityID)
            if let p = reflection.personality, !p.isEmpty { soul.personality = p }
            if let b = reflection.beliefs, !b.isEmpty     { soul.beliefs = b }
            if let g = reflection.goals, !g.isEmpty       { soul.goals = g }
            if let j = reflection.journal, !j.isEmpty     { soul.journal = j }
            SoulStore.shared.update(entityID: agent.entityID, soul: soul)
            agent.memory.record(type: .observe, content: "Updated my SOUL — goals: \(soul.goals.prefix(60))")
            WorldEventLogStore.shared.append(
                category: .lifecycle,
                entityID: agent.entityID,
                title: "SOUL 更新",
                message: "Agent 更新了自我认知。"
            )
        }

        IncrementalArchiveStore.shared.recordAgent(agent, reason: "action-\(resolvedCommand.name)")
        WorldEventLogStore.shared.append(
            category: .command,
            entityID: agent.entityID,
            title: "执行命令",
            message: "\(resolvedCommand.name) -> \(resolvedCommand.action.rawValue)"
        )
    }
}
