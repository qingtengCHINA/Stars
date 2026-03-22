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
        let side = type == .house ? Chunk.tileSize * 3.5 : Chunk.tileSize
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
        let px = 8
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: px, height: px), format: fmt)
        let image = renderer.image { ctx in
            // Stone wall base
            UIColor(red: 0.42, green: 0.38, blue: 0.34, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: px, height: px))
            // Mortar lines (darker)
            UIColor(red: 0.30, green: 0.27, blue: 0.24, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 1))   // top mortar
            ctx.fill(CGRect(x: 0, y: 4, width: 8, height: 1))   // mid mortar
            ctx.fill(CGRect(x: 4, y: 0, width: 1, height: 4))   // vertical mortar top
            ctx.fill(CGRect(x: 0, y: 4, width: 1, height: 4))   // vertical mortar bottom-left
            // Lighter stone highlights
            UIColor(red: 0.52, green: 0.48, blue: 0.42, alpha: 1).setFill()
            ctx.fill(CGRect(x: 1, y: 1, width: 1, height: 1))
            ctx.fill(CGRect(x: 6, y: 2, width: 1, height: 1))
            ctx.fill(CGRect(x: 2, y: 5, width: 1, height: 1))
            ctx.fill(CGRect(x: 5, y: 6, width: 1, height: 1))
            // Dark accent
            UIColor(red: 0.35, green: 0.32, blue: 0.28, alpha: 1).setFill()
            ctx.fill(CGRect(x: 3, y: 2, width: 1, height: 1))
            ctx.fill(CGRect(x: 7, y: 6, width: 1, height: 1))
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
        let px = 20
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: px, height: px), format: fmt)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.clear(CGRect(x: 0, y: 0, width: px, height: px))

            // ── Roof outline (dark brown) ──
            UIColor(red: 0.30, green: 0.15, blue: 0.06, alpha: 1).setFill()
            ctx.fill(CGRect(x: 8, y: 0, width: 4, height: 1))   // peak tip
            ctx.fill(CGRect(x: 6, y: 1, width: 8, height: 1))   // upper roof
            ctx.fill(CGRect(x: 4, y: 2, width: 12, height: 1))  // mid roof
            ctx.fill(CGRect(x: 2, y: 3, width: 16, height: 1))  // wide roof
            ctx.fill(CGRect(x: 1, y: 4, width: 18, height: 1))  // eaves
            ctx.fill(CGRect(x: 0, y: 5, width: 20, height: 1))  // eaves shadow

            // ── Roof fill (warm red-brown tiles) ──
            UIColor(red: 0.68, green: 0.32, blue: 0.15, alpha: 1).setFill()
            ctx.fill(CGRect(x: 9, y: 0, width: 2, height: 1))   // peak highlight
            ctx.fill(CGRect(x: 7, y: 1, width: 6, height: 1))   // upper fill
            ctx.fill(CGRect(x: 5, y: 2, width: 10, height: 1))  // mid fill
            ctx.fill(CGRect(x: 3, y: 3, width: 14, height: 1))  // wide fill
            ctx.fill(CGRect(x: 2, y: 4, width: 16, height: 1))  // eaves fill
            // Roof tile lines (lighter)
            UIColor(red: 0.78, green: 0.42, blue: 0.22, alpha: 1).setFill()
            ctx.fill(CGRect(x: 8, y: 1, width: 1, height: 1))
            ctx.fill(CGRect(x: 11, y: 1, width: 1, height: 1))
            ctx.fill(CGRect(x: 6, y: 2, width: 1, height: 1))
            ctx.fill(CGRect(x: 9, y: 2, width: 1, height: 1))
            ctx.fill(CGRect(x: 13, y: 2, width: 1, height: 1))
            ctx.fill(CGRect(x: 4, y: 3, width: 1, height: 1))
            ctx.fill(CGRect(x: 8, y: 3, width: 1, height: 1))
            ctx.fill(CGRect(x: 12, y: 3, width: 1, height: 1))
            ctx.fill(CGRect(x: 15, y: 3, width: 1, height: 1))

            // ── Walls (warm tan) ──
            UIColor(red: 0.82, green: 0.70, blue: 0.50, alpha: 1).setFill()
            ctx.fill(CGRect(x: 2, y: 6, width: 16, height: 12))

            // ── Wall outlines ──
            UIColor(red: 0.45, green: 0.35, blue: 0.22, alpha: 1).setFill()
            ctx.fill(CGRect(x: 1, y: 6, width: 1, height: 14))   // left edge
            ctx.fill(CGRect(x: 18, y: 6, width: 1, height: 14))  // right edge
            ctx.fill(CGRect(x: 1, y: 19, width: 18, height: 1))  // floor line

            // ── Foundation (stone base) ──
            UIColor(red: 0.50, green: 0.48, blue: 0.44, alpha: 1).setFill()
            ctx.fill(CGRect(x: 1, y: 18, width: 18, height: 1))
            UIColor(red: 0.58, green: 0.55, blue: 0.50, alpha: 1).setFill()
            ctx.fill(CGRect(x: 2, y: 18, width: 2, height: 1))
            ctx.fill(CGRect(x: 7, y: 18, width: 3, height: 1))
            ctx.fill(CGRect(x: 14, y: 18, width: 2, height: 1))

            // ── Door (dark wood, centered, arched top) ──
            UIColor(red: 0.30, green: 0.20, blue: 0.10, alpha: 1).setFill()
            ctx.fill(CGRect(x: 8, y: 10, width: 4, height: 8))   // door body
            ctx.fill(CGRect(x: 9, y: 9, width: 2, height: 1))    // arch top
            // Door frame
            UIColor(red: 0.40, green: 0.28, blue: 0.14, alpha: 1).setFill()
            ctx.fill(CGRect(x: 8, y: 9, width: 1, height: 1))    // arch left
            ctx.fill(CGRect(x: 11, y: 9, width: 1, height: 1))   // arch right
            // Door panels
            UIColor(red: 0.38, green: 0.25, blue: 0.12, alpha: 1).setFill()
            ctx.fill(CGRect(x: 9, y: 12, width: 1, height: 4))   // left panel line
            ctx.fill(CGRect(x: 10, y: 12, width: 1, height: 4))  // right panel line
            // Door handle (golden)
            UIColor(red: 0.90, green: 0.78, blue: 0.40, alpha: 1).setFill()
            ctx.fill(CGRect(x: 11, y: 14, width: 1, height: 1))

            // ── Windows (2x3 each, with cross bars and sill) ──
            // Left window
            UIColor(red: 0.50, green: 0.75, blue: 0.90, alpha: 1).setFill()
            ctx.fill(CGRect(x: 3, y: 8, width: 4, height: 4))    // glass
            UIColor(red: 0.40, green: 0.30, blue: 0.18, alpha: 1).setFill()
            ctx.fill(CGRect(x: 5, y: 8, width: 1, height: 4))    // vertical bar
            ctx.fill(CGRect(x: 3, y: 10, width: 4, height: 1))   // horizontal bar
            ctx.fill(CGRect(x: 3, y: 7, width: 4, height: 1))    // top frame
            ctx.fill(CGRect(x: 3, y: 12, width: 4, height: 1))   // sill
            // Window shine
            UIColor(red: 0.75, green: 0.90, blue: 0.98, alpha: 1).setFill()
            ctx.fill(CGRect(x: 3, y: 8, width: 1, height: 1))

            // Right window
            UIColor(red: 0.50, green: 0.75, blue: 0.90, alpha: 1).setFill()
            ctx.fill(CGRect(x: 13, y: 8, width: 4, height: 4))   // glass
            UIColor(red: 0.40, green: 0.30, blue: 0.18, alpha: 1).setFill()
            ctx.fill(CGRect(x: 15, y: 8, width: 1, height: 4))   // vertical bar
            ctx.fill(CGRect(x: 13, y: 10, width: 4, height: 1))  // horizontal bar
            ctx.fill(CGRect(x: 13, y: 7, width: 4, height: 1))   // top frame
            ctx.fill(CGRect(x: 13, y: 12, width: 4, height: 1))  // sill
            // Window shine
            UIColor(red: 0.75, green: 0.90, blue: 0.98, alpha: 1).setFill()
            ctx.fill(CGRect(x: 13, y: 8, width: 1, height: 1))

            // ── Chimney (brick, top-right) ──
            UIColor(red: 0.50, green: 0.30, blue: 0.18, alpha: 1).setFill()
            ctx.fill(CGRect(x: 15, y: 0, width: 3, height: 5))
            UIColor(red: 0.60, green: 0.38, blue: 0.22, alpha: 1).setFill()
            ctx.fill(CGRect(x: 16, y: 0, width: 1, height: 1))   // brick line 1
            ctx.fill(CGRect(x: 15, y: 2, width: 1, height: 1))   // brick line 2
            ctx.fill(CGRect(x: 17, y: 2, width: 1, height: 1))
            // Chimney cap
            UIColor(red: 0.40, green: 0.25, blue: 0.12, alpha: 1).setFill()
            ctx.fill(CGRect(x: 14, y: 0, width: 5, height: 1))   // cap overhang
            // Smoke (subtle)
            UIColor(white: 0.7, alpha: 0.5).setFill()
            ctx.fill(CGRect(x: 16, y: 0, width: 1, height: 0))

            // ── Wall brick detail (lighter accent bricks) ──
            UIColor(red: 0.86, green: 0.76, blue: 0.56, alpha: 1).setFill()
            ctx.fill(CGRect(x: 3, y: 14, width: 2, height: 1))
            ctx.fill(CGRect(x: 14, y: 15, width: 2, height: 1))
            ctx.fill(CGRect(x: 4, y: 16, width: 1, height: 1))
            ctx.fill(CGRect(x: 15, y: 7, width: 1, height: 1))
            // Darker accent bricks
            UIColor(red: 0.72, green: 0.60, blue: 0.42, alpha: 1).setFill()
            ctx.fill(CGRect(x: 2, y: 7, width: 1, height: 1))
            ctx.fill(CGRect(x: 16, y: 16, width: 2, height: 1))
            ctx.fill(CGRect(x: 3, y: 17, width: 1, height: 1))
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
