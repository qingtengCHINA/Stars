//
//  Structure.swift
//  Stars
//
//  Tile-aligned building placed by Agents: walls block movement, traps deal damage.
//

import SpriteKit

final class Structure: SKSpriteNode {

    let entityID: String
    let structureType: StructureType
    var hp: Int
    let maxHP: Int
    var ownerID: String?   // entityID of the builder (for house ownership)

    // MARK: - Init

    init(type: StructureType,
         tileX: Int,
         tileY: Int,
         entityID: String = UUID().uuidString,
         startingHP: Int? = nil,
         ownerID: String? = nil) {
        self.entityID = entityID
        self.structureType = type
        self.ownerID = ownerID
        self.maxHP = type.maxHP
        self.hp = max(1, min(startingHP ?? type.maxHP, type.maxHP))

        let texture = Self.createTexture(for: type)
        let side = type == .house ? Chunk.tileSize * 2.5 : Chunk.tileSize
        let size = CGSize(width: side, height: side)

        super.init(texture: texture, color: .clear, size: size)
        self.name = type.rawValue
        self.position = CGPoint(
            x: CGFloat(tileX) * Chunk.tileSize + Chunk.tileSize / 2,
            y: CGFloat(tileY) * Chunk.tileSize + Chunk.tileSize / 2
        )
        // Dynamic z-sort: lower y (closer to camera) renders in front
        self.zPosition = ZSort.depthZ(for: position.y)

        setupPhysics(type: type, size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Physics

    private func setupPhysics(type: StructureType, size: CGSize) {
        // Physics body always uses tile-sized collision — visual size may differ (e.g. house is 2.5x)
        let physicsSize = type == .house
            ? CGSize(width: Chunk.tileSize, height: Chunk.tileSize)
            : size
        let body = SKPhysicsBody(rectangleOf: physicsSize)
        body.isDynamic = false
        body.friction = 0
        body.restitution = 0

        switch type {
        case .wall:
            body.categoryBitMask    = PhysicsCategory.structure
            body.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.melee
            body.collisionBitMask   = PhysicsCategory.agent
        case .trap:
            body.categoryBitMask    = PhysicsCategory.trap
            body.contactTestBitMask = PhysicsCategory.agent
            body.collisionBitMask   = PhysicsCategory.none   // agents walk over traps
        case .house:
            body.categoryBitMask    = PhysicsCategory.structure
            body.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.melee
            body.collisionBitMask   = PhysicsCategory.none   // agents can enter houses
        }

        self.physicsBody = body
    }

    // MARK: - Damage

    func takeDamage(_ amount: Int) {
        guard hp > 0 else { return }
        hp = max(0, hp - amount)

        // Flash red
        run(SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.8, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.15),
        ]))

        if hp <= 0 {
            destroy()
        }
    }

    private func destroy() {
        physicsBody = nil
        run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.scale(to: 0.5, duration: 0.2),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    // MARK: - Pixel Textures (cached — only rendered once per type)

    private static let cachedWallTexture: SKTexture = {
        let px = 4
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: px, height: px), format: fmt)
        let image = renderer.image { ctx in
            UIColor(red: 0.30, green: 0.25, blue: 0.20, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: px, height: px))
            UIColor(red: 0.60, green: 0.50, blue: 0.40, alpha: 1).setFill()
            ctx.fill(CGRect(x: 1, y: 1, width: 2, height: 2))
        }
        let tex = SKTexture(image: image); tex.filteringMode = .nearest; return tex
    }()

    private static let cachedTrapTexture: SKTexture = {
        let px = 4
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: px, height: px), format: fmt)
        let image = renderer.image { ctx in
            UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: px, height: px))
            UIColor(red: 0.70, green: 0.20, blue: 0.20, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            ctx.fill(CGRect(x: 2, y: 2, width: 1, height: 1))
            ctx.fill(CGRect(x: 0, y: 3, width: 1, height: 1))
            ctx.fill(CGRect(x: 3, y: 0, width: 1, height: 1))
        }
        let tex = SKTexture(image: image); tex.filteringMode = .nearest; return tex
    }()

    private static let cachedHouseTexture: SKTexture = {
        let px = 12
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: px, height: px), format: fmt)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.clear(CGRect(x: 0, y: 0, width: px, height: px))

            // Roof outline (dark brown)
            UIColor(red: 0.35, green: 0.18, blue: 0.08, alpha: 1).setFill()
            ctx.fill(CGRect(x: 4, y: 0, width: 4, height: 1))   // peak
            ctx.fill(CGRect(x: 2, y: 1, width: 8, height: 1))   // mid roof
            ctx.fill(CGRect(x: 1, y: 2, width: 10, height: 1))  // wide roof
            ctx.fill(CGRect(x: 0, y: 3, width: 12, height: 1))  // eaves

            // Roof fill (warm brown)
            UIColor(red: 0.62, green: 0.35, blue: 0.18, alpha: 1).setFill()
            ctx.fill(CGRect(x: 5, y: 0, width: 2, height: 1))   // peak highlight
            ctx.fill(CGRect(x: 3, y: 1, width: 6, height: 1))   // mid fill
            ctx.fill(CGRect(x: 2, y: 2, width: 8, height: 1))   // wide fill

            // Walls (warm tan)
            UIColor(red: 0.78, green: 0.65, blue: 0.45, alpha: 1).setFill()
            ctx.fill(CGRect(x: 1, y: 4, width: 10, height: 7))

            // Wall outline left + right
            UIColor(red: 0.45, green: 0.35, blue: 0.22, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 4, width: 1, height: 8))   // left wall edge
            ctx.fill(CGRect(x: 11, y: 4, width: 1, height: 8))  // right wall edge
            ctx.fill(CGRect(x: 0, y: 11, width: 12, height: 1)) // floor line

            // Door (dark brown, centered)
            UIColor(red: 0.30, green: 0.22, blue: 0.12, alpha: 1).setFill()
            ctx.fill(CGRect(x: 5, y: 7, width: 2, height: 5))

            // Door handle (light)
            UIColor(red: 0.85, green: 0.75, blue: 0.50, alpha: 1).setFill()
            ctx.fill(CGRect(x: 6, y: 9, width: 1, height: 1))

            // Windows (sky blue, left and right of door)
            UIColor(red: 0.55, green: 0.78, blue: 0.92, alpha: 1).setFill()
            ctx.fill(CGRect(x: 2, y: 5, width: 2, height: 2))   // left window
            ctx.fill(CGRect(x: 8, y: 5, width: 2, height: 2))   // right window

            // Window cross bars (dark)
            UIColor(red: 0.40, green: 0.30, blue: 0.18, alpha: 1).setFill()
            ctx.fill(CGRect(x: 3, y: 5, width: 1, height: 2))   // left window vertical bar
            ctx.fill(CGRect(x: 2, y: 6, width: 2, height: 1))   // left window horizontal bar (overlap is fine)
            // Simplify - just the cross on right window
            ctx.fill(CGRect(x: 9, y: 5, width: 1, height: 2))   // right window vertical bar

            // Chimney (optional detail, top-right)
            UIColor(red: 0.42, green: 0.28, blue: 0.15, alpha: 1).setFill()
            ctx.fill(CGRect(x: 9, y: 0, width: 2, height: 3))

            // Wall texture detail (a few lighter bricks)
            UIColor(red: 0.82, green: 0.72, blue: 0.52, alpha: 1).setFill()
            ctx.fill(CGRect(x: 2, y: 8, width: 2, height: 1))
            ctx.fill(CGRect(x: 8, y: 9, width: 2, height: 1))
        }
        let tex = SKTexture(image: image); tex.filteringMode = .nearest; return tex
    }()

    private static func createTexture(for type: StructureType) -> SKTexture {
        switch type {
        case .wall:  return cachedWallTexture
        case .trap:  return cachedTrapTexture
        case .house: return cachedHouseTexture
        }
    }
}
