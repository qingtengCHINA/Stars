//
//  Chunk.swift
//  Stars
//

import SpriteKit

struct ChunkCoord: Hashable, Sendable {
    let x: Int
    let y: Int
}

final class Chunk: SKSpriteNode {
    let coord: ChunkCoord

    static let tileSize: CGFloat = 16
    static let tileCount: Int = 16
    static let worldSize: CGFloat = tileSize * CGFloat(tileCount) // 256

    init(coord: ChunkCoord, tiles: [[TileType]]) {
        self.coord = coord

        let texture = Self.renderTexture(from: tiles)
        let size = CGSize(width: Self.worldSize, height: Self.worldSize)

        super.init(texture: texture, color: .clear, size: size)
        self.anchorPoint = CGPoint(x: 0, y: 0)
        self.position = CGPoint(
            x: CGFloat(coord.x) * Self.worldSize,
            y: CGFloat(coord.y) * Self.worldSize
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Simple integer hash for pseudo-random dithering (no visible pattern).
    @inline(__always)
    private static func tileHash(_ x: Int, _ y: Int) -> Int {
        var h = x &* 374761393 &+ y &* 668265263
        h = (h ^ (h >> 13)) &* 1274126177
        return h ^ (h >> 16)
    }

    // Renders a 16x16 pixel texture (1 pixel per tile) with sparse
    // pseudo-random sub-pixel variation to break up flat color blocks.
    // Nearest-neighbor filtering preserves the pixel-art look.
    private static func renderTexture(from tiles: [[TileType]]) -> SKTexture {
        let count = tileCount
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: count, height: count),
            format: format
        )

        let image = renderer.image { ctx in
            for iy in 0..<count {
                let tileY = count - 1 - iy // flip Y: image top → world top
                for ix in 0..<count {
                    let tile = tiles[tileY][ix]

                    // Hash-based pseudo-random: ~25% of tiles get altColor
                    let h = tileHash(ix, iy)
                    let useAlt = (h & 3) == 0 // 25% probability

                    if useAlt {
                        tile.altColor.setFill()
                    } else {
                        tile.color.setFill()
                    }
                    ctx.fill(CGRect(x: ix, y: iy, width: 1, height: 1))

                    // Sparse accent detail for flowers, water (~12% of tiles)
                    if let detail = tile.detailColor,
                       (h & 7) == 1 {
                        detail.setFill()
                        ctx.fill(CGRect(x: ix, y: iy, width: 1, height: 1))
                    }
                }
            }
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
}
