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

    // MARK: - Init

    init(type: StructureType,
         tileX: Int,
         tileY: Int,
         entityID: String = UUID().uuidString,
         startingHP: Int? = nil) {
        self.entityID = entityID
        self.structureType = type
        self.maxHP = type.maxHP
        self.hp = max(1, min(startingHP ?? type.maxHP, type.maxHP))

        let texture = Self.createTexture(for: type)
        let side = Chunk.tileSize
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
        let body = SKPhysicsBody(rectangleOf: size)
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

    private static func createTexture(for type: StructureType) -> SKTexture {
        switch type {
        case .wall: return cachedWallTexture
        case .trap: return cachedTrapTexture
        }
    }
}
