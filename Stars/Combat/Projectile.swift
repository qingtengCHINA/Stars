//
//  Projectile.swift
//  Stars
//
//  A small, fast-moving bullet fired by ranged attacks.
//  Removed on contact or after its lifetime expires.
//

import SpriteKit

final class Projectile: SKSpriteNode {

    private(set) var ownerID: String
    private(set) var damage: Int

    init(ownerID: String, damage: Int, direction: CGVector, speed: CGFloat) {
        self.ownerID = ownerID
        self.damage = damage

        let texture = Self.cachedTexture
        super.init(texture: texture, color: .clear, size: CGSize(width: 4, height: 4))
        self.zPosition = ZSort.projectile
        self.name = "projectile"

        setupPhysics(direction: direction, speed: speed)
        scheduleAutoRecycle()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Pooling Support

    /// Reconfigure a recycled projectile for reuse.
    func reconfigure(ownerID: String, damage: Int,
                     direction: CGVector, speed: CGFloat) {
        self.ownerID = ownerID
        self.damage = damage
        self.alpha = 1.0

        if let body = physicsBody {
            body.categoryBitMask    = PhysicsCategory.projectile
            body.contactTestBitMask = PhysicsCategory.agent | PhysicsCategory.structure
            body.collisionBitMask   = PhysicsCategory.none
            body.velocity = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)
        } else {
            setupPhysics(direction: direction, speed: speed)
        }

        scheduleAutoRecycle()
    }

    private func setupPhysics(direction: CGVector, speed: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: 2)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0
        body.categoryBitMask    = PhysicsCategory.projectile
        body.contactTestBitMask = PhysicsCategory.agent | PhysicsCategory.structure
        body.collisionBitMask   = PhysicsCategory.none
        body.velocity = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)
        self.physicsBody = body
    }

    private func scheduleAutoRecycle() {
        removeAllActions()
        run(SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in
                guard let self else { return }
                ProjectilePool.shared.recycle(self)
            },
        ]))
    }

    // 2×2 yellow pixel — cached to avoid re-rendering on every shot
    private static let cachedTexture: SKTexture = {
        let px = 2
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: px, height: px), format: fmt)
        let image = renderer.image { ctx in
            UIColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: px, height: px))
        }
        let tex = SKTexture(image: image); tex.filteringMode = .nearest; return tex
    }()
}
