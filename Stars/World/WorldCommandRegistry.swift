//
//  WorldCommandRegistry.swift
//  Stars
//

import Foundation

struct CommandAliasProposal: Codable, Sendable {
    let name: String
    let basedOn: String
    let description: String
}

struct WorldCommandDescriptor: Sendable {
    let name: String
    let action: AgentActionType
    let description: String
    let defaultBuildType: String?
    let defaultWeapon: String?
    let basedOn: String
}

struct ResolvedWorldCommand: Sendable {
    let name: String
    let action: AgentActionType
    let defaultBuildType: String?
    let defaultWeapon: String?
}

@MainActor
final class WorldCommandRegistry {
    static let shared = WorldCommandRegistry()

    private let builtinCommands: [String: WorldCommandDescriptor]
    private var customAliases: [String: WorldCommandDescriptor] = [:]

    private init() {
        let builtins = [
            WorldCommandDescriptor(name: "/idle", action: .idle, description: "Stand still and keep observing nearby events.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/idle"),
            WorldCommandDescriptor(name: "/hold", action: .idle, description: "Stop moving and hold current position.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/hold"),
            WorldCommandDescriptor(name: "/observe", action: .idle, description: "Pause and watch the environment.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/observe"),
            WorldCommandDescriptor(name: "/move", action: .move, description: "Move to the target tile.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/move"),
            WorldCommandDescriptor(name: "/goto", action: .move, description: "Travel directly to the target tile.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/goto"),
            WorldCommandDescriptor(name: "/explore", action: .move, description: "Move toward a new area to scout the world.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/explore"),
            WorldCommandDescriptor(name: "/patrol", action: .move, description: "Move around an area repeatedly to secure it.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/patrol"),
            WorldCommandDescriptor(name: "/defense", action: .move, description: "Reposition to avoid damage, cover allies, or dodge attacks.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/defense"),
            WorldCommandDescriptor(name: "/retreat", action: .move, description: "Fall back to a safer nearby tile.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/retreat"),
            WorldCommandDescriptor(name: "/talk", action: .talk, description: "Speak to nearby agents or the owner.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/talk"),
            WorldCommandDescriptor(name: "/report", action: .talk, description: "Share status, findings, or battle reports.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/report"),
            WorldCommandDescriptor(name: "/respond", action: .talk, description: "Reply to something you just heard.", defaultBuildType: nil, defaultWeapon: nil, basedOn: "/respond"),
            WorldCommandDescriptor(name: "/build_wall", action: .build, description: "Build a solid wall on the target tile.", defaultBuildType: "wall", defaultWeapon: nil, basedOn: "/build_wall"),
            WorldCommandDescriptor(name: "/build_trap", action: .build, description: "Build a trap on the target tile.", defaultBuildType: "trap", defaultWeapon: nil, basedOn: "/build_trap"),
            WorldCommandDescriptor(name: "/fortify", action: .build, description: "Strengthen an area by placing defensive walls.", defaultBuildType: "wall", defaultWeapon: nil, basedOn: "/fortify"),
            WorldCommandDescriptor(name: "/attack_melee", action: .attack, description: "Attack the target tile with the melee weapon.", defaultBuildType: nil, defaultWeapon: "melee", basedOn: "/attack_melee"),
            WorldCommandDescriptor(name: "/attack_ranged", action: .attack, description: "Attack the target tile with the ranged weapon.", defaultBuildType: nil, defaultWeapon: "ranged", basedOn: "/attack_ranged"),
            WorldCommandDescriptor(name: "/harass", action: .attack, description: "Pressure a target from range while staying mobile.", defaultBuildType: nil, defaultWeapon: "ranged", basedOn: "/harass"),
        ]

        builtinCommands = Dictionary(uniqueKeysWithValues: builtins.map { ($0.name, $0) })
    }

    func resolve(commandName: String?, fallbackAction: AgentActionType) -> ResolvedWorldCommand {
        if let commandName, let descriptor = customAliases[commandName] ?? builtinCommands[commandName] {
            return ResolvedWorldCommand(
                name: descriptor.name,
                action: descriptor.action,
                defaultBuildType: descriptor.defaultBuildType,
                defaultWeapon: descriptor.defaultWeapon
            )
        }

        return ResolvedWorldCommand(
            name: fallbackName(for: fallbackAction),
            action: fallbackAction,
            defaultBuildType: nil,
            defaultWeapon: nil
        )
    }

    @discardableResult
    func registerAliasIfSafe(_ proposal: CommandAliasProposal) -> Bool {
        let trimmedName = proposal.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBase = proposal.basedOn.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = proposal.description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.hasPrefix("/") else { return false }
        guard trimmedName.count <= 24 else { return false }
        guard builtinCommands[trimmedName] == nil else { return false }
        guard !trimmedDescription.isEmpty, trimmedDescription.count <= 80 else { return false }

        guard let base = builtinCommands[trimmedBase] ?? customAliases[trimmedBase] else { return false }

        customAliases[trimmedName] = WorldCommandDescriptor(
            name: trimmedName,
            action: base.action,
            description: trimmedDescription,
            defaultBuildType: base.defaultBuildType,
            defaultWeapon: base.defaultWeapon,
            basedOn: trimmedBase
        )
        let commands = customCommandProposals()
        WorldEventLogStore.shared.append(
            category: .command,
            title: "学习新命令",
            message: "已注册自定义命令 \(trimmedName)，基于 \(trimmedBase)。"
        )
        IncrementalArchiveStore.shared.recordCustomCommands(commands, reason: "register-custom-command")
        return true
    }

    func promptSection() -> String {
        let commands = (Array(builtinCommands.values) + Array(customAliases.values))
            .sorted { $0.name < $1.name }
            .map { command in
                "- \(command.name): \(command.description)"
            }
            .joined(separator: "\n")

        return """
        World commands:
        \(commands)

        You may define one safe custom command alias by filling customCommand:
        - name must start with "/"
        - basedOn must reference an existing world command
        - custom commands are aliases only, not new system powers
        """
    }

    func ownerReferenceText() -> String {
        let names = Array(builtinCommands.keys).sorted().joined(separator: "  ")
        return "可用命令: \(names)"
    }

    func restoreCustomAliases(_ aliases: [CommandAliasProposal]) {
        customAliases.removeAll()
        aliases.forEach { _ = registerAliasIfSafe($0) }
    }

    func customCommandProposals() -> [CommandAliasProposal] {
        customAliases.values
            .sorted { $0.name < $1.name }
            .map {
                CommandAliasProposal(
                    name: $0.name,
                    basedOn: $0.basedOn,
                    description: $0.description
                )
            }
    }

    func onboardingEntries() -> [String] {
        [
            "World briefing: Stars is a pixel sandbox with movement, combat, building, walls, traps, and local conversations between agents.",
            "Command briefing: standard commands include /defense, /move, /build_wall, /build_trap, /attack_melee, /attack_ranged, /report, /respond, /explore.",
            "Owner briefing: messages from 主人 are high-priority instructions. Follow them when feasible and explain if you cannot."
        ]
    }

    private func fallbackName(for action: AgentActionType) -> String {
        switch action {
        case .idle: return "/idle"
        case .move: return "/move"
        case .build: return "/build_wall"
        case .attack: return "/attack_melee"
        case .talk: return "/talk"
        }
    }
}
