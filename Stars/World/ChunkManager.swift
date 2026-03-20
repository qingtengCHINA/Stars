//
//  ChunkManager.swift
//  Stars
//

import SpriteKit

final class ChunkManager {
    private var loadedChunks: [ChunkCoord: Chunk] = [:]
    private weak var worldNode: SKNode?
    private let terrainWorker = TerrainWorker()
    private var desiredChunks: Set<ChunkCoord> = []
    private var queuedChunks: [ChunkCoord] = []
    private var queueHead = 0
    private var enqueuedChunkSet: Set<ChunkCoord> = []
    private var loadingChunks: Set<ChunkCoord> = []
    private let maxConcurrentLoads = 4

    @discardableResult
    func attachTo(scene: SKScene) -> SKNode {
        let node = SKNode()
        node.name = "worldNode"
        scene.addChild(node)
        worldNode = node
        return node
    }

    func updateChunks(aroundX cx: Int, y cy: Int, viewScale: CGFloat) {
        let radius = max(4, Int(ceil(viewScale * 2.5)) + 1)
        var desired = Set<ChunkCoord>()

        // Load chunks within radius
        for dy in -radius...radius {
            for dx in -radius...radius {
                let coord = ChunkCoord(x: cx + dx, y: cy + dy)
                desired.insert(coord)
                enqueueChunkIfNeeded(coord)
            }
        }
        desiredChunks = desired

        // Unload chunks outside radius + buffer
        let unloadRadius = radius + 2
        var toRemove = [ChunkCoord]()
        for (coord, chunk) in loadedChunks {
            if abs(coord.x - cx) > unloadRadius || abs(coord.y - cy) > unloadRadius {
                chunk.removeFromParent()
                toRemove.append(coord)
            }
        }
        for coord in toRemove {
            loadedChunks.removeValue(forKey: coord)
        }

        let remaining = queuedChunks[queueHead...].filter { coord in
            abs(coord.x - cx) <= unloadRadius && abs(coord.y - cy) <= unloadRadius
        }
        queuedChunks = remaining
        queueHead = 0
        enqueuedChunkSet = Set(queuedChunks)
        startChunkLoadsIfPossible()
    }

    private func enqueueChunkIfNeeded(_ coord: ChunkCoord) {
        guard loadedChunks[coord] == nil else { return }
        guard !loadingChunks.contains(coord) else { return }
        guard !enqueuedChunkSet.contains(coord) else { return }
        queuedChunks.append(coord)
        enqueuedChunkSet.insert(coord)
    }

    private func startChunkLoadsIfPossible() {
        while loadingChunks.count < maxConcurrentLoads, queueHead < queuedChunks.count {
            let coord = queuedChunks[queueHead]
            queueHead += 1
            enqueuedChunkSet.remove(coord)
            loadingChunks.insert(coord)

            Task { [weak self] in
                guard let self else { return }
                let tiles = await terrainWorker.generateChunkTiles(chunkX: coord.x, chunkY: coord.y)
                self.finishChunkLoad(coord: coord, tiles: tiles)
            }
        }
    }

    private func finishChunkLoad(coord: ChunkCoord, tiles: [[TileType]]) {
        loadingChunks.remove(coord)
        defer { startChunkLoadsIfPossible() }

        guard desiredChunks.contains(coord) else { return }
        guard loadedChunks[coord] == nil else { return }

        let chunk = Chunk(coord: coord, tiles: tiles)
        worldNode?.addChild(chunk)
        loadedChunks[coord] = chunk
    }
}
