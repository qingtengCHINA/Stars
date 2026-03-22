//
//  GameStateStore.swift
//  Stars
//

import Foundation
import SpriteKit
import UIKit

extension Notification.Name {
    static let starsPersistWorldState = Notification.Name("stars.persistWorldState")
}

struct RGBAColor: Codable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }

    var uiColor: UIColor {
        UIColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
}

struct AgentSnapshot: Codable, Sendable {
    let entityID: String
    let modelConfigID: UUID
    let displayName: String
    let positionX: Double
    let positionY: Double
    let hp: Int
    let moveSpeed: Double
    let color: RGBAColor
    let currentThought: String?
    let currentAction: AgentActionType
    let memories: [MemoryEntry]
    let chatMessages: [ChatMessageEntry]
    let shortTermMessages: [ShortTermMessage]
    let forceNextThink: Bool
    let pendingOwnerReplies: Int
    let respawnRemaining: Double
    let stars: Int
    let houseRestAccumulator: Double
    let visitedChunks: [String]
    let weaponAmmo: [String: Int]
    let revivalCards: Int

    init(
        entityID: String,
        modelConfigID: UUID,
        displayName: String,
        positionX: Double,
        positionY: Double,
        hp: Int,
        moveSpeed: Double,
        color: RGBAColor,
        currentThought: String?,
        currentAction: AgentActionType,
        memories: [MemoryEntry],
        chatMessages: [ChatMessageEntry],
        shortTermMessages: [ShortTermMessage],
        forceNextThink: Bool,
        pendingOwnerReplies: Int,
        respawnRemaining: Double,
        stars: Int = 0,
        houseRestAccumulator: Double = 0,
        visitedChunks: [String] = [],
        weaponAmmo: [String: Int] = [:],
        revivalCards: Int = 0
    ) {
        self.entityID = entityID
        self.modelConfigID = modelConfigID
        self.displayName = displayName
        self.positionX = positionX
        self.positionY = positionY
        self.hp = hp
        self.moveSpeed = moveSpeed
        self.color = color
        self.currentThought = currentThought
        self.currentAction = currentAction
        self.memories = memories
        self.chatMessages = chatMessages
        self.shortTermMessages = shortTermMessages
        self.forceNextThink = forceNextThink
        self.pendingOwnerReplies = pendingOwnerReplies
        self.respawnRemaining = respawnRemaining
        self.stars = stars
        self.houseRestAccumulator = houseRestAccumulator
        self.visitedChunks = visitedChunks
        self.weaponAmmo = weaponAmmo
        self.revivalCards = revivalCards
    }

    enum CodingKeys: String, CodingKey {
        case entityID, modelConfigID, displayName, positionX, positionY
        case hp, moveSpeed, color, currentThought, currentAction
        case memories, chatMessages, shortTermMessages, forceNextThink
        case pendingOwnerReplies, respawnRemaining, stars, houseRestAccumulator
        case visitedChunks, weaponAmmo, revivalCards
        case ownedWeapons // legacy key for backward compatibility
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityID = try container.decode(String.self, forKey: .entityID)
        modelConfigID = try container.decode(UUID.self, forKey: .modelConfigID)
        displayName = try container.decode(String.self, forKey: .displayName)
        positionX = try container.decode(Double.self, forKey: .positionX)
        positionY = try container.decode(Double.self, forKey: .positionY)
        hp = try container.decode(Int.self, forKey: .hp)
        moveSpeed = try container.decode(Double.self, forKey: .moveSpeed)
        color = try container.decode(RGBAColor.self, forKey: .color)
        currentThought = try container.decodeIfPresent(String.self, forKey: .currentThought)
        currentAction = try container.decode(AgentActionType.self, forKey: .currentAction)
        memories = try container.decode([MemoryEntry].self, forKey: .memories)
        chatMessages = try container.decodeIfPresent([ChatMessageEntry].self, forKey: .chatMessages) ?? []
        shortTermMessages = try container.decodeIfPresent([ShortTermMessage].self, forKey: .shortTermMessages) ?? []
        forceNextThink = try container.decodeIfPresent(Bool.self, forKey: .forceNextThink) ?? false
        pendingOwnerReplies = try container.decodeIfPresent(Int.self, forKey: .pendingOwnerReplies) ?? 0
        respawnRemaining = try container.decodeIfPresent(Double.self, forKey: .respawnRemaining) ?? 0
        stars = try container.decodeIfPresent(Int.self, forKey: .stars) ?? 0
        houseRestAccumulator = try container.decodeIfPresent(Double.self, forKey: .houseRestAccumulator) ?? 0
        visitedChunks = try container.decodeIfPresent([String].self, forKey: .visitedChunks) ?? []
        // Backward-compatible: try new weaponAmmo first, fall back to old ownedWeapons
        if let ammo = try container.decodeIfPresent([String: Int].self, forKey: .weaponAmmo) {
            weaponAmmo = ammo
        } else if let oldWeapons = try container.decodeIfPresent([String].self, forKey: .ownedWeapons) {
            // Migrate: convert old Set<String> to ammo dict (give ammoPerPurchase for each)
            var migrated = [String: Int]()
            for id in oldWeapons where !WeaponCatalog.defaultWeapons.contains(id) {
                migrated[id] = WeaponCatalog.weapon(for: id).ammoPerPurchase
            }
            weaponAmmo = migrated
        } else {
            weaponAmmo = [:]
        }
        revivalCards = try container.decodeIfPresent(Int.self, forKey: .revivalCards) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entityID, forKey: .entityID)
        try container.encode(modelConfigID, forKey: .modelConfigID)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(positionX, forKey: .positionX)
        try container.encode(positionY, forKey: .positionY)
        try container.encode(hp, forKey: .hp)
        try container.encode(moveSpeed, forKey: .moveSpeed)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(currentThought, forKey: .currentThought)
        try container.encode(currentAction, forKey: .currentAction)
        try container.encode(memories, forKey: .memories)
        try container.encode(chatMessages, forKey: .chatMessages)
        try container.encode(shortTermMessages, forKey: .shortTermMessages)
        try container.encode(forceNextThink, forKey: .forceNextThink)
        try container.encode(pendingOwnerReplies, forKey: .pendingOwnerReplies)
        try container.encode(respawnRemaining, forKey: .respawnRemaining)
        try container.encode(stars, forKey: .stars)
        try container.encode(houseRestAccumulator, forKey: .houseRestAccumulator)
        try container.encode(visitedChunks, forKey: .visitedChunks)
        try container.encode(weaponAmmo, forKey: .weaponAmmo)
        try container.encode(revivalCards, forKey: .revivalCards)
        // Note: ownedWeapons (legacy key) is intentionally NOT encoded
    }

    init(agent: Agent) {
        self.init(
            entityID: agent.entityID,
            modelConfigID: agent.representedModelConfigID,
            displayName: agent.displayName,
            positionX: agent.position.x,
            positionY: agent.position.y,
            hp: agent.hp,
            moveSpeed: Double(agent.moveSpeed),
            color: RGBAColor(agent.agentColor),
            currentThought: agent.currentThought,
            currentAction: agent.currentAction,
            memories: agent.memory.allEntries(),
            chatMessages: agent.chatMessages,
            shortTermMessages: agent.shortTermMessages,
            forceNextThink: agent.forceNextThink,
            pendingOwnerReplies: agent.pendingOwnerReplies,
            respawnRemaining: agent.respawnRemaining,
            stars: agent.stars,
            houseRestAccumulator: agent.houseRestAccumulator,
            visitedChunks: Array(agent.visitedChunks),
            weaponAmmo: agent.weaponAmmo,
            revivalCards: agent.revivalCards
        )
    }
}

struct StructureSnapshot: Codable, Sendable {
    let entityID: String
    let type: StructureType
    let tileX: Int
    let tileY: Int
    let hp: Int
    let ownerID: String?

    init(entityID: String, type: StructureType, tileX: Int, tileY: Int, hp: Int, ownerID: String? = nil) {
        self.entityID = entityID
        self.type = type
        self.tileX = tileX
        self.tileY = tileY
        self.hp = hp
        self.ownerID = ownerID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityID = try container.decode(String.self, forKey: .entityID)
        type = try container.decode(StructureType.self, forKey: .type)
        tileX = try container.decode(Int.self, forKey: .tileX)
        tileY = try container.decode(Int.self, forKey: .tileY)
        hp = try container.decode(Int.self, forKey: .hp)
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID)
    }

    init(structure: Structure) {
        self.init(
            entityID: structure.entityID,
            type: structure.structureType,
            tileX: Int(floor(structure.position.x / Chunk.tileSize)),
            tileY: Int(floor(structure.position.y / Chunk.tileSize)),
            hp: structure.hp,
            ownerID: structure.ownerID
        )
    }
}

struct CameraSnapshot: Codable, Sendable {
    let x: Double
    let y: Double
    let scale: Double
}

struct GameStateSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let savedAt: Date
    let agents: [AgentSnapshot]
    let structures: [StructureSnapshot]
    let camera: CameraSnapshot
    let customCommands: [CommandAliasProposal]
    let worldTimeMinutes: Double

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        savedAt: Date,
        agents: [AgentSnapshot],
        structures: [StructureSnapshot],
        camera: CameraSnapshot,
        customCommands: [CommandAliasProposal],
        worldTimeMinutes: Double = 360
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.agents = agents
        self.structures = structures
        self.camera = camera
        self.customCommands = customCommands
        self.worldTimeMinutes = worldTimeMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        agents = try container.decode([AgentSnapshot].self, forKey: .agents)
        structures = try container.decode([StructureSnapshot].self, forKey: .structures)
        camera = try container.decode(CameraSnapshot.self, forKey: .camera)
        customCommands = try container.decodeIfPresent([CommandAliasProposal].self, forKey: .customCommands) ?? []
        worldTimeMinutes = try container.decodeIfPresent(Double.self, forKey: .worldTimeMinutes) ?? 360
    }

    static let currentSchemaVersion = 3
}

final class GameStateStore {
    static let shared = GameStateStore()

    private let legacyStorageKey = "stars.game.state"
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {}

    func save(_ snapshot: GameStateSnapshot) {
        do {
            let data = try encoder.encode(snapshot)
            let url = try snapshotURL()
            let directoryURL = url.deletingLastPathComponent()
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: url, options: .atomic)
            try excludeFromBackup(url: url)
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        } catch {
            print("[Persistence] Failed to save world state: \(error.localizedDescription)")
        }
    }

    func load() -> GameStateSnapshot? {
        if let snapshot = loadFromFile() {
            return snapshot
        }

        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey) else { return nil }
        guard let snapshot = try? decoder.decode(GameStateSnapshot.self, from: data) else { return nil }
        save(snapshot)
        return snapshot
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        if let url = try? snapshotURL(), fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func loadFromFile() -> GameStateSnapshot? {
        guard let url = try? snapshotURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(GameStateSnapshot.self, from: data)
    }

    private func snapshotURL() throws -> URL {
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return baseDirectory
            .appendingPathComponent("Stars", isDirectory: true)
            .appendingPathComponent("game-state.json", isDirectory: false)
    }

    private func excludeFromBackup(url: URL) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(resourceValues)
    }
}
