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

    // Renders a 16x16 pixel texture (1 pixel per tile) with nearest-neighbor filtering
    // for crisp pixel-art upscaling to 256x256 points.
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
                    tiles[tileY][ix].color.setFill()
                    ctx.fill(CGRect(x: ix, y: iy, width: 1, height: 1))
                }
            }
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
}
