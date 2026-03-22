//
//  BuildSystem.swift
//  Stars
//
//  Manages placement and lifecycle of structures on the world grid.
//

import SpriteKit

final class BuildSystem {

    private(set) var structures: [Structure] = []
    private weak var worldNode: SKNode?
    private(set) var needsCleanup = false

    func attachTo(worldNode: SKNode) {
        self.worldNode = worldNode
    }

    // MARK: - Placement

    /// Place a structure at the given tile.  Returns nil if the tile is occupied.
    @discardableResult
    func placeStructure(type: StructureType, tileX: Int, tileY: Int,
                        builder: Agent) -> Structure? {
        guard canBuilderReachTile(builder: builder, tileX: tileX, tileY: tileY) else {
            builder.memory.record(type: .build, content: "Build failed: target tile is too far away.")
            WorldEventLogStore.shared.append(
                category: .build,
                entityID: builder.entityID,
                title: NSLocalizedString("log.build_failed", comment: ""),
                message: String(format: NSLocalizedString("log.build_fail_range", comment: ""), tileX, tileY)
            )
            return nil
        }
        guard terrainAllowsStructure(atTileX: tileX, tileY: tileY) else {
            builder.memory.record(type: .build, content: "Build failed: cannot build on this terrain.")
            WorldEventLogStore.shared.append(
                category: .build,
                entityID: builder.entityID,
                title: NSLocalizedString("log.build_failed", comment: ""),
                message: String(format: NSLocalizedString("log.build_fail_terrain", comment: ""), tileX, tileY)
            )
            return nil
        }
        guard !isTileOccupied(tileX: tileX, tileY: tileY) else {
            builder.memory.record(type: .build, content: "Build failed: target tile is occupied.")
            WorldEventLogStore.shared.append(
                category: .build,
                entityID: builder.entityID,
                title: NSLocalizedString("log.build_failed", comment: ""),
                message: String(format: NSLocalizedString("log.build_fail_occupied", comment: ""), tileX, tileY)
            )
            return nil
        }

        // Economy: building costs Stars
        let cost = type.buildCost
        guard builder.spendStars(cost, reason: "Build \(type.rawValue)") else {
            builder.memory.record(type: .build, content: "Build failed: not enough Stars. Need \(cost)⭐, have \(builder.stars)⭐.")
            WorldEventLogStore.shared.append(
                category: .build,
                entityID: builder.entityID,
                title: NSLocalizedString("log.build_failed", comment: ""),
                message: "Not enough Stars to build \(type.rawValue). Need \(cost)⭐, have \(builder.stars)⭐."
            )
            return nil
        }

        return createStructure(type: type, tileX: tileX, tileY: tileY, builder: builder)
    }

    @discardableResult
    func restoreStructures(_ snapshots: [StructureSnapshot]) -> [Structure] {
        clearAllStructures()

        var restored = [Structure]()
        for snapshot in snapshots where snapshot.hp > 0 {
            let structure = Structure(
                type: snapshot.type,
                tileX: snapshot.tileX,
                tileY: snapshot.tileY,
                entityID: snapshot.entityID,
                startingHP: snapshot.hp,
                ownerID: snapshot.ownerID
            )
            worldNode?.addChild(structure)
            structures.append(structure)
            restored.append(structure)
        }

        return restored
    }

    func clearAllStructures() {
        for structure in structures {
            structure.removeAllActions()
            structure.removeFromParent()
        }
        structures.removeAll()
    }

    private func createStructure(type: StructureType, tileX: Int, tileY: Int,
                                 builder: Agent?) -> Structure? {
        let structure = Structure(type: type, tileX: tileX, tileY: tileY, ownerID: builder?.entityID)
        worldNode?.addChild(structure)
        structures.append(structure)

        // Builder pays a time cost
        builder?.startBuildCooldown(1.5)
        if let builder {
            // Record build success in builder's memory
            builder.memory.record(type: .build, content: "Successfully built a \(type.rawValue) at (\(tileX), \(tileY)).")
            IncrementalArchiveStore.shared.recordAgent(builder, reason: "build-cooldown")
            WorldEventLogStore.shared.append(
                category: .build,
                entityID: builder.entityID,
                title: NSLocalizedString("log.build_complete", comment: ""),
                message: String(format: NSLocalizedString("log.build_complete_msg", comment: ""), tileX, tileY, type.rawValue)
            )
        }
        IncrementalArchiveStore.shared.recordStructure(structure, reason: "structure-created")

        return structure
    }

    // MARK: - Cleanup

    func markNeedsCleanup() {
        needsCleanup = true
    }

    func removeDestroyedStructures() {
        guard needsCleanup else { return }
        needsCleanup = false
        for structure in structures where structure.hp <= 0 || structure.parent == nil {
            IncrementalArchiveStore.shared.recordStructure(structure, reason: "structure-destroyed")
            WorldEventLogStore.shared.append(
                category: .build,
                entityID: structure.entityID,
                title: NSLocalizedString("log.structure_destroyed", comment: ""),
                message: String(format: NSLocalizedString("log.structure_destroyed_msg", comment: ""), structure.structureType.rawValue)
            )
        }
        structures.removeAll { $0.hp <= 0 || $0.parent == nil }
    }

    func snapshots() -> [StructureSnapshot] {
        structures
            .filter { $0.hp > 0 && $0.parent != nil }
            .map { StructureSnapshot(structure: $0) }
    }

    // MARK: - Entity Queries

    func structuresNear(_ position: CGPoint, tileRadius: Int) -> [EntityInfo] {
        let cx = Int(floor(position.x / Chunk.tileSize))
        let cy = Int(floor(position.y / Chunk.tileSize))

        return structures.compactMap { s in
            guard s.hp > 0 else { return nil }
            let sx = Int(floor(s.position.x / Chunk.tileSize))
            let sy = Int(floor(s.position.y / Chunk.tileSize))
            guard abs(sx - cx) <= tileRadius && abs(sy - cy) <= tileRadius else { return nil }
            let ownerSuffix = s.ownerID.map { " owner:\($0.prefix(8))" } ?? ""
            return EntityInfo(
                id: s.entityID,
                type: s.structureType.rawValue,
                name: "\(s.structureType.rawValue) (HP:\(s.hp)/\(s.maxHP))\(ownerSuffix)",
                tileX: sx,
                tileY: sy
            )
        }
    }

    /// Returns the tile coordinates of the agent's own house, or nil if none exists.
    func findOwnHouseTile(_ agent: Agent) -> (tileX: Int, tileY: Int)? {
        guard let house = structures.first(where: {
            $0.structureType == .house &&
            $0.ownerID == agent.entityID &&
            $0.hp > 0
        }) else { return nil }
        return (
            tileX: Int(floor(house.position.x / Chunk.tileSize)),
            tileY: Int(floor(house.position.y / Chunk.tileSize))
        )
    }

    /// Returns true if the agent is standing on their own house tile.
    func isAgentInOwnHouse(_ agent: Agent) -> Bool {
        guard let tile = findOwnHouseTile(agent) else { return false }
        return tile.tileX == agent.tileX && tile.tileY == agent.tileY
    }

    private func canBuilderReachTile(builder: Agent, tileX: Int, tileY: Int) -> Bool {
        let dx = abs(builder.tileX - tileX)
        let dy = abs(builder.tileY - tileY)
        return max(dx, dy) <= 1
    }

    private func terrainAllowsStructure(atTileX tileX: Int, tileY: Int) -> Bool {
        let tile = TerrainGenerator.shared.tile(atTileX: tileX, tileY: tileY)
        switch tile {
        case .deepWater, .water:
            return false
        default:
            return true
        }
    }

    private func isTileOccupied(tileX: Int, tileY: Int) -> Bool {
        if structures.contains(where: { structure in
            structure.hp > 0 &&
            Int(floor(structure.position.x / Chunk.tileSize)) == tileX &&
            Int(floor(structure.position.y / Chunk.tileSize)) == tileY
        }) {
            return true
        }

        guard let worldNode else { return false }
        for case let agent as Agent in worldNode.children where !agent.isDead {
            if agent.tileX == tileX && agent.tileY == tileY {
                return true
            }
        }
        return false
    }
}
