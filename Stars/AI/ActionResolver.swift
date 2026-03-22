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

    /// Set by AgentManager to look up the agent's own house tile coordinates.
    static var findOwnHouse: ((Agent) -> (tileX: Int, tileY: Int)?)?

    /// Set by AgentManager to look up agents by entity ID (prefix match).
    static var agentLookup: ((String) -> Agent?)?

    /// Set by AgentManager to revive a dead agent (for Revival Card).
    static var reviveAgent: ((Agent) -> Void)?

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

        // --- System reactions for special commands ---
        // /rest and /enter_house both auto-navigate to own house
        if resolvedCommand.name == "/rest" || resolvedCommand.name == "/enter_house" {
            let isRest = resolvedCommand.name == "/rest"
            handleHouseNavigation(
                agent: agent, response: response,
                resolvedCommand: resolvedCommand, replyText: replyText,
                successMemory: isRest ? "Heading home to rest" : "Going to my house",
                failMemory: isRest
                    ? "Wanted to rest but I have no house. Need to /build_house first."
                    : "Cannot enter house — I don't own one. Build with /build_house first."
            )
            return
        }

        // --- Economy & item commands (all map to action: talk) ---
        if let economyCommand = resolvedCommand.name as String?,
           ["/pay", "/offer_trade", "/accept_trade", "/decline_trade", "/bounty", "/cancel_bounty", "/hire", "/buy_weapon", "/buy_revival", "/revive"].contains(economyCommand) {
            handleEconomyCommand(
                commandName: economyCommand,
                agent: agent, response: response,
                resolvedCommand: resolvedCommand, replyText: replyText
            )
            return
        }

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
                let bType: StructureType = StructureType(rawValue: buildTypeName) ?? .wall
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
            // Resolve weapon: try catalog first, then fall back to melee/ranged
            let resolvedWeaponID: String
            if WeaponCatalog.all[weaponName] != nil && agent.ownedWeapons.contains(weaponName) {
                resolvedWeaponID = weaponName
            } else if weaponName == "ranged" || weaponName == "melee" {
                // Legacy "melee"/"ranged" — use best owned weapon in that category
                resolvedWeaponID = weaponName == "melee" ? "fist" : "pistol"
            } else {
                // Unknown weapon or not owned — fall back to fist/pistol
                resolvedWeaponID = resolvedCommand.defaultWeapon == "ranged" ? "pistol" : "fist"
                if WeaponCatalog.all[weaponName] != nil {
                    agent.memory.record(type: .observe, content: "Don't own \(weaponName). Buy it with /buy_weapon first. Using default.")
                }
            }
            agent.pendingWeaponID = resolvedWeaponID
            agent.pendingWeapon = WeaponCatalog.physicsCategory(for: resolvedWeaponID)
            let weaponLabel = WeaponCatalog.weapon(for: resolvedWeaponID).displayName
            if let t = response.target, let x = t.x, let y = t.y {
                agent.moveTo(tileX: x, tileY: y)
                if let replyText, !replyText.isEmpty {
                    agent.showSpeechBubble(replyText)
                    agent.recordAgentReply(replyText)
                }
                agent.memory.record(
                    type: .combat,
                    content: "Executing \(resolvedCommand.name): attacking (\(x), \(y)) with \(weaponLabel)"
                )
            }
        }

        handleSoulReflection(response, agent: agent, resolvedCommand: resolvedCommand)
    }

    // MARK: - Economy Commands

    /// Handles all economy-related commands: /pay, /offer_trade, /accept_trade, /decline_trade, /bounty, /cancel_bounty, /hire.
    private static func handleEconomyCommand(
        commandName: String,
        agent: Agent, response: LLMResponse,
        resolvedCommand: ResolvedWorldCommand, replyText: String?
    ) {
        let target = response.target
        let recipientPrefix = target?.recipientID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let starsAmount = target?.starsAmount ?? 0

        // Resolve recipient agent by prefix match
        let recipient = resolveRecipient(prefix: recipientPrefix)

        switch commandName {
        case "/pay":
            if let recipient, starsAmount > 0 {
                let success = TradeManager.shared.pay(from: agent, to: recipient, amount: starsAmount)
                if success {
                    let speech = replyText ?? "Paid \(starsAmount)⭐ to \(recipient.displayName)."
                    agent.showSpeechBubble(speech)
                    agent.recordAgentReply(speech)
                    talkBroadcast?(agent, speech)
                }
            } else {
                agent.memory.record(type: .observe, content: "Pay failed: need recipientID and starsAmount > 0.")
            }

        case "/offer_trade":
            if let recipient, starsAmount > 0 {
                let description = response.speech ?? response.thought
                let offer = TradeManager.shared.createOffer(
                    offeror: agent,
                    recipientID: recipient.entityID,
                    recipientName: recipient.displayName,
                    starsAmount: starsAmount,
                    description: description
                )
                if offer != nil {
                    let speech = replyText ?? "I offer \(starsAmount)⭐ to \(recipient.displayName)."
                    agent.showSpeechBubble(speech)
                    agent.recordAgentReply(speech)
                    talkBroadcast?(agent, speech)
                    // Notify recipient to think about the offer
                    recipient.forceNextThink = true
                }
            } else {
                agent.memory.record(type: .observe, content: "Trade offer failed: need recipientID and starsAmount > 0.")
            }

        case "/accept_trade":
            if !recipientPrefix.isEmpty {
                let offerorAgent = resolveRecipient(prefix: recipientPrefix)
                let success = TradeManager.shared.acceptTrade(acceptor: agent, offerorID: offerorAgent?.entityID ?? recipientPrefix)
                if success {
                    let speech = replyText ?? "Trade accepted!"
                    agent.showSpeechBubble(speech)
                    agent.recordAgentReply(speech)
                    talkBroadcast?(agent, speech)
                    // Notify offeror about acceptance
                    offerorAgent?.forceNextThink = true
                    if let offerorAgent {
                        offerorAgent.memory.record(type: .talk, content: "\(agent.displayName) accepted your trade offer!")
                    }
                }
            } else {
                agent.memory.record(type: .observe, content: "Accept trade failed: need recipientID (offeror's ID prefix).")
            }

        case "/decline_trade":
            if !recipientPrefix.isEmpty {
                let offerorAgent = resolveRecipient(prefix: recipientPrefix)
                let success = TradeManager.shared.declineTrade(
                    decliner: agent,
                    offerorID: offerorAgent?.entityID ?? recipientPrefix,
                    refundTo: offerorAgent
                )
                if success {
                    let speech = replyText ?? "Trade declined."
                    agent.showSpeechBubble(speech)
                    agent.recordAgentReply(speech)
                    talkBroadcast?(agent, speech)
                    offerorAgent?.forceNextThink = true
                    if let offerorAgent {
                        offerorAgent.memory.record(type: .talk, content: "\(agent.displayName) declined your trade offer. Stars refunded.")
                    }
                }
            } else {
                agent.memory.record(type: .observe, content: "Decline trade failed: need recipientID (offeror's ID prefix).")
            }

        case "/bounty":
            if let recipient, starsAmount > 0 {
                let reason = response.speech ?? response.thought
                let bounty = BountyBoard.shared.postBounty(
                    poster: agent,
                    targetID: recipient.entityID,
                    targetName: recipient.displayName,
                    reward: starsAmount,
                    reason: reason
                )
                if bounty != nil {
                    let speech = replyText ?? "Bounty posted: \(starsAmount)⭐ on \(recipient.displayName)!"
                    agent.showSpeechBubble(speech)
                    agent.recordAgentReply(speech)
                    talkBroadcast?(agent, speech)
                }
            } else {
                agent.memory.record(type: .observe, content: "Bounty failed: need recipientID (target) and starsAmount > 0.")
            }

        case "/cancel_bounty":
            if !recipientPrefix.isEmpty {
                let targetAgent = resolveRecipient(prefix: recipientPrefix)
                let success = BountyBoard.shared.cancelBounty(
                    poster: agent,
                    targetID: targetAgent?.entityID ?? recipientPrefix
                )
                if success {
                    let speech = replyText ?? "Bounty cancelled."
                    agent.showSpeechBubble(speech)
                    agent.recordAgentReply(speech)
                    talkBroadcast?(agent, speech)
                }
            } else {
                agent.memory.record(type: .observe, content: "Cancel bounty failed: need recipientID (target's ID prefix).")
            }

        case "/hire":
            if let recipient, starsAmount > 0 {
                let success = TradeManager.shared.pay(from: agent, to: recipient, amount: starsAmount)
                if success {
                    let task = response.speech ?? response.thought
                    let speech = replyText ?? "Hired \(recipient.displayName) for \(starsAmount)⭐."
                    agent.showSpeechBubble(speech)
                    agent.recordAgentReply(speech)
                    talkBroadcast?(agent, speech)
                    agent.memory.record(type: .talk, content: "Hired \(recipient.displayName) for \(starsAmount)⭐: \"\(task)\"")
                    recipient.memory.record(type: .talk, content: "Hired by \(agent.displayName) for \(starsAmount)⭐: \"\(task)\"")
                    LongTermMemory.shared.recordSocialFact(
                        entityID: recipient.entityID,
                        content: "Hired by \(agent.displayName) for \(starsAmount)⭐ to: \"\(task)\""
                    )
                    recipient.forceNextThink = true
                }
            } else {
                agent.memory.record(type: .observe, content: "Hire failed: need recipientID and starsAmount > 0.")
            }

        case "/buy_weapon":
            let weaponID = response.target?.weapon ?? response.speech?.lowercased()
                .components(separatedBy: .whitespaces)
                .first(where: { WeaponCatalog.all[$0] != nil }) ?? ""
            if let def = WeaponCatalog.all[weaponID] {
                if def.cost == 0 {
                    agent.memory.record(type: .observe, content: "\(def.displayName) is free — already have unlimited ammo.")
                } else if agent.spendStars(def.cost, reason: "Buy \(def.displayName)") {
                    agent.addAmmo(weaponID: weaponID, amount: def.ammoPerPurchase)
                    let currentAmmo = agent.ammoCount(for: weaponID)
                    agent.memory.record(type: .observe, content: "Purchased \(def.displayName) for \(def.cost)⭐! Got \(def.ammoPerPurchase) rounds (total ammo: \(currentAmmo)).")
                    let speech = replyText ?? "Bought \(def.displayName) (\(def.ammoPerPurchase) rounds)!"
                    agent.showSpeechBubble(speech)
                    agent.recordAgentReply(speech)
                    talkBroadcast?(agent, speech)
                    WorldEventLogStore.shared.append(
                        category: .command, entityID: agent.entityID,
                        title: "Weapon Purchased",
                        message: "\(agent.displayName) bought \(def.displayName) for \(def.cost)⭐ (\(def.ammoPerPurchase) rounds)"
                    )
                } else {
                    agent.memory.record(type: .observe, content: "Cannot afford \(def.displayName): need \(def.cost)⭐, have \(agent.stars)⭐.")
                }
            } else {
                agent.memory.record(type: .observe, content: "Unknown weapon: \(weaponID). Check weapon shop for valid IDs.")
            }

        case "/buy_revival":
            let revivalCost = EconomyConfig.shared.revivalCardCost
            if agent.spendStars(revivalCost, reason: "Buy Revival Card") {
                agent.revivalCards += 1
                agent.memory.record(type: .observe, content: "Purchased a Revival Card for \(revivalCost)⭐! Total cards: \(agent.revivalCards)")
                let speech = replyText ?? "Got a Revival Card! 💚"
                agent.showSpeechBubble(speech)
                agent.recordAgentReply(speech)
                talkBroadcast?(agent, speech)
                WorldEventLogStore.shared.append(
                    category: .command, entityID: agent.entityID,
                    title: "Revival Card Purchased",
                    message: "\(agent.displayName) bought a Revival Card for \(revivalCost)⭐"
                )
            } else {
                agent.memory.record(type: .observe, content: "Cannot afford Revival Card: need \(revivalCost)⭐, have \(agent.stars)⭐.")
            }

        case "/revive":
            if agent.revivalCards <= 0 {
                agent.memory.record(type: .observe, content: "No Revival Cards. Buy one with /buy_revival (150⭐).")
            } else if !recipientPrefix.isEmpty, let target = recipient {
                // Revive another agent
                if target.isDead {
                    agent.revivalCards -= 1
                    reviveAgent?(target)
                    agent.memory.record(type: .talk, content: "Used Revival Card to revive \(target.displayName)! Cards remaining: \(agent.revivalCards)")
                    let speech = replyText ?? "Revived \(target.displayName)! 💚"
                    agent.showSpeechBubble(speech)
                    agent.recordAgentReply(speech)
                    talkBroadcast?(agent, speech)
                    LongTermMemory.shared.recordSocialFact(
                        entityID: target.entityID,
                        content: "Revived by \(agent.displayName) using a Revival Card."
                    )
                    WorldEventLogStore.shared.append(
                        category: .command, entityID: agent.entityID,
                        title: "Agent Revived",
                        message: "\(agent.displayName) revived \(target.displayName) with a Revival Card"
                    )
                } else {
                    agent.memory.record(type: .observe, content: "\(target.displayName) is not dead. Revival Card not used.")
                }
            } else if agent.isDead {
                // Self-revive — handled by system since dead agents can't think
                agent.memory.record(type: .observe, content: "Cannot self-revive while alive. Use /revive with recipientID to revive dead allies.")
            } else {
                agent.memory.record(type: .observe, content: "Revive failed: need recipientID of a dead agent, or be dead yourself.")
            }

        default:
            break
        }

        agent.clearTarget()
        handleSoulReflection(response, agent: agent, resolvedCommand: resolvedCommand)
    }

    /// Resolve an agent by entity ID prefix match.
    private static func resolveRecipient(prefix: String) -> Agent? {
        guard !prefix.isEmpty else { return nil }
        return agentLookup?(prefix)
    }

    // MARK: - House Navigation (shared by /rest and /enter_house)

    /// Unified handler for commands that auto-navigate to the agent's house.
    private static func handleHouseNavigation(
        agent: Agent, response: LLMResponse,
        resolvedCommand: ResolvedWorldCommand, replyText: String?,
        successMemory: String, failMemory: String
    ) {
        if let houseTile = findOwnHouse?(agent) {
            agent.moveTo(tileX: houseTile.tileX, tileY: houseTile.tileY)
            agent.currentAction = .move
            if let replyText, !replyText.isEmpty {
                agent.showSpeechBubble(replyText)
                agent.recordAgentReply(replyText)
            }
            agent.memory.record(type: .move, content: "\(successMemory) at (\(houseTile.tileX), \(houseTile.tileY)).")
        } else {
            agent.clearTarget()
            agent.memory.record(type: .observe, content: failMemory)
            if let replyText, !replyText.isEmpty {
                agent.showSpeechBubble(replyText)
                agent.recordAgentReply(replyText)
            }
        }
        handleSoulReflection(response, agent: agent, resolvedCommand: resolvedCommand)
    }

    // MARK: - Soul Reflection & Logging

    /// Handles soul reflection updates and command logging.
    /// Extracted so special commands (/rest, /enter_house) can share this logic.
    private static func handleSoulReflection(
        _ response: LLMResponse,
        agent: Agent,
        resolvedCommand: ResolvedWorldCommand
    ) {
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
                title: NSLocalizedString("log.soul_updated", comment: ""),
                message: NSLocalizedString("log.soul_updated_msg", comment: "")
            )
        }

        IncrementalArchiveStore.shared.recordAgent(agent, reason: "action-\(resolvedCommand.name)")
        WorldEventLogStore.shared.append(
            category: .command,
            entityID: agent.entityID,
            title: NSLocalizedString("log.command_executed", comment: ""),
            message: "\(resolvedCommand.name) -> \(resolvedCommand.action.rawValue)"
        )
    }
}
