//
//  TerrainGenerator.swift
//  Stars
//

import Foundation

final class TerrainGenerator {
    static let shared = TerrainGenerator()

    private init() {}

    func generateChunkTiles(chunkX: Int, chunkY: Int) -> [[TileType]] {
        Self.generateChunkTilesStatic(chunkX: chunkX, chunkY: chunkY)
    }

    func tile(atTileX tileX: Int, tileY: Int) -> TileType {
        Self.tileAt(worldX: tileX, worldY: tileY)
    }

    nonisolated fileprivate static func generateChunkTilesStatic(chunkX: Int, chunkY: Int) -> [[TileType]] {
        let count = 16
        var tiles = [[TileType]](
            repeating: [TileType](repeating: .grass, count: count),
            count: count
        )

        for y in 0..<count {
            for x in 0..<count {
                let worldX = chunkX * count + x
                let worldY = chunkY * count + y
                tiles[y][x] = tileAt(worldX: worldX, worldY: worldY)
            }
        }

        return tiles
    }

    nonisolated private static func tileAt(worldX: Int, worldY: Int) -> TileType {
        if let handcrafted = handcraftedSpawnTile(worldX: worldX, worldY: worldY) {
            return handcrafted
        }

        let x = Double(worldX)
        let y = Double(worldY)

        let macro = fbm(x: x, y: y, seed: 11, scale: 110, octaves: 4)
        let moisture = fbm(x: x + 1900, y: y - 2400, seed: 23, scale: 62, octaves: 3)
        let richness = fbm(x: x - 900, y: y + 1200, seed: 31, scale: 24, octaves: 3)
        let ridge = ridgedFbm(x: x + 600, y: y - 300, seed: 71, scale: 54, octaves: 3)
        let trail = abs(fbm(x: x + 4400, y: y - 1700, seed: 97, scale: 34, octaves: 2) - 0.5)

        if trail < 0.028 && macro > 0.28 && macro < 0.82 {
            return moisture > 0.58 ? .dirt : .sand
        }

        if macro < 0.18 { return .deepWater }
        if macro < 0.26 { return .water }
        if macro < 0.31 { return .sand }

        if ridge > 0.78 && macro > 0.56 { return .stone }
        if macro > 0.84 { return richness > 0.58 ? .stone : .dirt }

        if moisture > 0.74 {
            return richness > 0.62 ? .flowers : .darkGrass
        }

        if richness > 0.68 && moisture > 0.46 { return .flowers }
        if richness < 0.22 && macro > 0.60 { return .dirt }
        if macro > 0.63 { return .darkGrass }
        return .grass
    }

    nonisolated private static func handcraftedSpawnTile(worldX: Int, worldY: Int) -> TileType? {
        let dx = worldX - 8
        let dy = worldY - 8
        let distance = hypot(Double(dx), Double(dy))

        guard abs(dx) <= 18, abs(dy) <= 14 else { return nil }

        if distance < 5 {
            return .grass
        }

        if abs(dx) <= 1 || abs(dy) <= 1 {
            return distance < 13 ? .sand : .dirt
        }

        if distance > 14 && distance < 16 {
            return .darkGrass
        }

        if distance >= 16 {
            return abs(dx + dy) % 5 == 0 ? .flowers : .grass
        }

        return .grass
    }

    nonisolated private static func fbm(x: Double, y: Double, seed: Int, scale: Double, octaves: Int) -> Double {
        var total = 0.0
        var amplitude = 0.5
        var frequency = 1.0
        var normalization = 0.0

        for octave in 0..<octaves {
            total += amplitude * smoothNoise(
                x: x / scale * frequency,
                y: y / scale * frequency,
                seed: seed + octave * 997
            )
            normalization += amplitude
            amplitude *= 0.5
            frequency *= 2.0
        }

        return total / max(normalization, 0.0001)
    }

    nonisolated private static func ridgedFbm(x: Double, y: Double, seed: Int, scale: Double, octaves: Int) -> Double {
        let value = fbm(x: x, y: y, seed: seed, scale: scale, octaves: octaves)
        return 1.0 - abs(value * 2.0 - 1.0)
    }

    nonisolated private static func smoothNoise(x: Double, y: Double, seed: Int) -> Double {
        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let x1 = x0 + 1
        let y1 = y0 + 1

        let tx = smoothstep(x - floor(x))
        let ty = smoothstep(y - floor(y))

        let n00 = hashNoise(x: x0, y: y0, seed: seed)
        let n10 = hashNoise(x: x1, y: y0, seed: seed)
        let n01 = hashNoise(x: x0, y: y1, seed: seed)
        let n11 = hashNoise(x: x1, y: y1, seed: seed)

        let nx0 = lerp(n00, n10, tx)
        let nx1 = lerp(n01, n11, tx)
        return lerp(nx0, nx1, ty)
    }

    nonisolated private static func hashNoise(x: Int, y: Int, seed: Int) -> Double {
        var value = Int64(x) &* 374_761_393
        value &+= Int64(y) &* 668_265_263
        value &+= Int64(seed) &* 1_442_695_040
        value = (value ^ (value >> 13)) &* 1_274_126_177
        value ^= value >> 16
        return Double(value & 0x7fff_ffff) / Double(Int32.max)
    }

    nonisolated private static func smoothstep(_ t: Double) -> Double {
        t * t * (3.0 - 2.0 * t)
    }

    nonisolated private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private func floorDiv(_ value: Int, by divisor: Int) -> Int {
        let quotient = value / divisor
        let remainder = value % divisor
        return remainder >= 0 ? quotient : quotient - 1
    }

    private func positiveMod(_ value: Int, _ divisor: Int) -> Int {
        let mod = value % divisor
        return mod >= 0 ? mod : mod + divisor
    }
}

actor TerrainWorker {
    func generateChunkTiles(chunkX: Int, chunkY: Int) -> [[TileType]] {
        TerrainGenerator.generateChunkTilesStatic(chunkX: chunkX, chunkY: chunkY)
    }
}
