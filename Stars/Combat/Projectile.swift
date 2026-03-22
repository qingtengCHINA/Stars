//
//  Projectile.swift
//  Stars
//
//  A fast-moving projectile fired by ranged/explosive attacks.
//  Supports weapon-specific pixel-art textures with glow trails.
//  Removed on contact or after its lifetime expires.
//

import SpriteKit

final class Projectile: SKSpriteNode {

    private(set) var ownerID: String
    private(set) var damage: Int
    private(set) var weaponID: String
    private(set) var isHoming: Bool = false
    private(set) var projectileSpeed: CGFloat = 0
    weak var homingTarget: Agent?
    private var trail: SKNode?

    init(ownerID: String, damage: Int, direction: CGVector,
         speed: CGFloat, weaponID: String = "pistol",
         homingTarget: Agent? = nil) {
        self.ownerID = ownerID
        self.damage = damage
        self.weaponID = weaponID
        self.projectileSpeed = speed

        let def = WeaponCatalog.weapon(for: weaponID)
        self.isHoming = def.isHoming && homingTarget != nil
        let texture = Self.texture(for: def)
        // Use texture's actual pixel dimensions for proper aspect ratio
        let texW = texture.size().width
        let texH = texture.size().height
        let scale: CGFloat = 2.0  // 2× display scale for pixel art
        super.init(texture: texture, color: .clear,
                   size: CGSize(width: texW * scale, height: texH * scale))
        self.zPosition = ZSort.projectile
        self.name = "projectile"
        self.homingTarget = homingTarget

        // Rotate sprite to face direction
        self.zRotation = atan2(direction.dy, direction.dx)

        setupPhysics(direction: direction, speed: speed)
        attachTrail(for: def, direction: direction)
        if self.isHoming {
            startHomingTracking()
        }
        scheduleAutoRecycle()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Pooling Support

    /// Reconfigure a recycled projectile for reuse.
    func reconfigure(ownerID: String, damage: Int,
                     direction: CGVector, speed: CGFloat,
                     weaponID: String = "pistol",
                     homingTarget: Agent? = nil) {
        self.ownerID = ownerID
        self.damage = damage
        self.weaponID = weaponID
        self.projectileSpeed = speed
        self.alpha = 1.0
        self.homingTarget = homingTarget

        // Update texture if weapon changed
        let def = WeaponCatalog.weapon(for: weaponID)
        self.isHoming = def.isHoming && homingTarget != nil
        let tex = Self.texture(for: def)
        self.texture = tex
        let texW = tex.size().width
        let texH = tex.size().height
        let scale: CGFloat = 2.0
        self.size = CGSize(width: texW * scale, height: texH * scale)
        self.zRotation = atan2(direction.dy, direction.dx)

        if let body = physicsBody {
            body.categoryBitMask    = PhysicsCategory.projectile
            body.contactTestBitMask = PhysicsCategory.agent | PhysicsCategory.structure
            body.collisionBitMask   = PhysicsCategory.none
            body.velocity = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)
        } else {
            setupPhysics(direction: direction, speed: speed)
        }

        // Refresh trail
        trail?.removeFromParent()
        trail = nil
        attachTrail(for: def, direction: direction)
        if self.isHoming {
            startHomingTracking()
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

    // MARK: - Weapon-Specific Trail Effects

    private func attachTrail(for def: WeaponDefinition, direction: CGVector) {
        let trailNode = SKNode()
        trailNode.zPosition = -1

        switch def.id {

        // ── HOMING WEAPONS: fiery exhaust trail ──
        case "missile", "rocket_launcher":
            for i in 1...8 {
                let t = CGFloat(i)
                let colors: [UIColor] = [
                    UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 0.9),
                    UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 0.8),
                    UIColor(red: 1, green: 0.3, blue: 0.0, alpha: 0.6),
                    UIColor(red: 0.8, green: 0.1, blue: 0.0, alpha: 0.4),
                ]
                let color = colors[min(i - 1, colors.count - 1) / 2]
                let size = CGFloat(max(1, 3 - i / 3))
                let dot = SKSpriteNode(color: color, size: CGSize(width: size, height: size))
                dot.position = CGPoint(x: -direction.dx * t * 1.8,
                                       y: -direction.dy * t * 1.8)
                trailNode.addChild(dot)
            }
            // Animated flicker
            trailNode.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.6, duration: 0.1),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1),
            ])))

        case "drone_strike":
            // Smoke trail — grey fading particles
            for i in 1...6 {
                let alpha = 0.6 * CGFloat(6 - i) / 6
                let dot = SKSpriteNode(color: UIColor(white: 0.7, alpha: alpha),
                                       size: CGSize(width: 2, height: 2))
                dot.position = CGPoint(x: -direction.dx * CGFloat(i) * 2.0,
                                       y: -direction.dy * CGFloat(i) * 2.0)
                trailNode.addChild(dot)
            }
            trailNode.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.3),
                SKAction.fadeAlpha(to: 0.7, duration: 0.3),
            ])))

        // ── LASER: bright cyan streak ──
        case "laser":
            for i in 1...10 {
                let alpha = 0.8 * CGFloat(10 - i) / 10
                let dot = SKSpriteNode(color: UIColor.cyan.withAlphaComponent(alpha),
                                       size: CGSize(width: 1, height: 1))
                dot.position = CGPoint(x: -direction.dx * CGFloat(i) * 1.2,
                                       y: -direction.dy * CGFloat(i) * 1.2)
                trailNode.addChild(dot)
            }
            // Rapid pulse
            trailNode.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 0.08),
                SKAction.fadeAlpha(to: 1.0, duration: 0.08),
            ])))

        // ── SNIPER: thin white tracer ──
        case "sniper":
            for i in 1...12 {
                let alpha = 0.9 * CGFloat(12 - i) / 12
                let dot = SKSpriteNode(color: UIColor.white.withAlphaComponent(alpha),
                                       size: CGSize(width: 1, height: 1))
                dot.position = CGPoint(x: -direction.dx * CGFloat(i) * 1.5,
                                       y: -direction.dy * CGFloat(i) * 1.5)
                trailNode.addChild(dot)
            }

        // ── PLASMA: purple energy particles ──
        case "plasma_cannon":
            for i in 1...6 {
                let alpha = 0.7 * CGFloat(6 - i) / 6
                let size = CGFloat(i % 2 == 0 ? 2 : 1)
                let dot = SKSpriteNode(color: def.color.withAlphaComponent(alpha),
                                       size: CGSize(width: size, height: size))
                dot.position = CGPoint(x: -direction.dx * CGFloat(i) * 2.0 + CGFloat.random(in: -1...1),
                                       y: -direction.dy * CGFloat(i) * 2.0 + CGFloat.random(in: -1...1))
                trailNode.addChild(dot)
            }
            trailNode.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.15),
                SKAction.fadeAlpha(to: 0.8, duration: 0.15),
            ])))

        // ── FLAMETHROWER: dissipating flame trail ──
        case "flamethrower":
            for i in 1...5 {
                let t = CGFloat(i)
                let color = UIColor(red: 1, green: 0.5 - t * 0.06, blue: 0,
                                    alpha: 0.7 * (5 - t) / 5)
                let size = CGFloat(3 - i / 2)
                let dot = SKSpriteNode(color: color,
                                       size: CGSize(width: max(1, size), height: max(1, size)))
                dot.position = CGPoint(x: -direction.dx * t * 1.5 + CGFloat.random(in: -2...2),
                                       y: -direction.dy * t * 1.5 + CGFloat.random(in: -2...2))
                trailNode.addChild(dot)
            }
            trailNode.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 0.12),
                SKAction.fadeAlpha(to: 0.8, duration: 0.12),
            ])))

        // ── GRENADE / MORTAR: short smoke puff ──
        case "grenade", "mortar":
            for i in 1...3 {
                let alpha = 0.5 * CGFloat(3 - i) / 3
                let dot = SKSpriteNode(color: UIColor(white: 0.5, alpha: alpha),
                                       size: CGSize(width: 2, height: 2))
                dot.position = CGPoint(x: -direction.dx * CGFloat(i) * 2.0,
                                       y: -direction.dy * CGFloat(i) * 2.0)
                trailNode.addChild(dot)
            }

        // ── POISON DART: green toxic mist ──
        case "poison_dart":
            for i in 1...4 {
                let alpha = 0.6 * CGFloat(4 - i) / 4
                let dot = SKSpriteNode(color: def.color.withAlphaComponent(alpha),
                                       size: CGSize(width: 1, height: 1))
                dot.position = CGPoint(x: -direction.dx * CGFloat(i) * 1.5 + CGFloat.random(in: -1...1),
                                       y: -direction.dy * CGFloat(i) * 1.5 + CGFloat.random(in: -1...1))
                trailNode.addChild(dot)
            }

        // ── CROSSBOW: minimal trail ──
        case "crossbow":
            for i in 1...2 {
                let dot = SKSpriteNode(color: def.color.withAlphaComponent(0.3),
                                       size: CGSize(width: 1, height: 1))
                dot.position = CGPoint(x: -direction.dx * CGFloat(i) * 2,
                                       y: -direction.dy * CGFloat(i) * 2)
                trailNode.addChild(dot)
            }

        // ── STANDARD BULLETS: basic muzzle trail ──
        case "pistol", "rifle", "smg", "shotgun":
            let len = def.speed >= 150 ? 5 : 3
            for i in 1...len {
                let alpha = 0.5 * CGFloat(len - i) / CGFloat(len)
                let dot = SKSpriteNode(color: def.color.withAlphaComponent(alpha),
                                       size: CGSize(width: 1, height: 1))
                dot.position = CGPoint(x: -direction.dx * CGFloat(i) * 1.5,
                                       y: -direction.dy * CGFloat(i) * 1.5)
                trailNode.addChild(dot)
            }

        default:
            // No trail for unrecognized weapons
            return
        }

        self.trail = trailNode
        addChild(trailNode)
    }

    private func scheduleAutoRecycle() {
        removeAllActions()
        run(SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in
                guard let self else { return }
                self.homingTarget = nil
                self.trail?.removeFromParent()
                self.trail = nil
                ProjectilePool.shared.recycle(self)
            },
        ]), withKey: "autoRecycle")
    }

    // MARK: - Homing Tracking

    /// Adjusts velocity toward the target agent every 0.05s (20Hz).
    private func startHomingTracking() {
        let track = SKAction.run { [weak self] in
            guard let self, let target = self.homingTarget else { return }
            guard !target.isDead else {
                self.homingTarget = nil  // target died, fly straight
                return
            }
            let dx = target.position.x - self.position.x
            let dy = target.position.y - self.position.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 1 else { return }
            let speed = self.projectileSpeed
            self.physicsBody?.velocity = CGVector(
                dx: (dx / dist) * speed,
                dy: (dy / dist) * speed
            )
            self.zRotation = atan2(dy, dx)
        }
        let wait = SKAction.wait(forDuration: 0.05)
        let trackLoop = SKAction.repeatForever(SKAction.sequence([wait, track]))
        run(trackLoop, withKey: "homing")
    }

    // MARK: - Weapon-Specific Textures (unique pixel art per weapon)

    private static var textureCache = [String: SKTexture]()

    /// Helper: render pixel art at 1x scale with transparent background.
    private static func renderPixelTexture(w: Int, h: Int,
                                            draw: (CGContext, Int, Int) -> Void) -> SKTexture {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: w, height: h), format: fmt
        )
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.clear(CGRect(x: 0, y: 0, width: w, height: h))
            draw(gc, w, h)
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
    }

    static func texture(for def: WeaponDefinition) -> SKTexture {
        if let cached = textureCache[def.id] { return cached }

        let tex: SKTexture
        switch def.id {

        // ── RANGED ──────────────────────────────────────
        case "pistol":
            // Small yellow round bullet
            tex = renderPixelTexture(w: 4, h: 4) { gc, _, _ in
                def.color.withAlphaComponent(0.3).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
                def.color.setFill()
                gc.fill(CGRect(x: 1, y: 1, width: 2, height: 2))
                UIColor.white.withAlphaComponent(0.8).setFill()
                gc.fill(CGRect(x: 2, y: 1, width: 1, height: 1))
            }

        case "rifle":
            // Elongated orange bullet with bright white tip
            tex = renderPixelTexture(w: 7, h: 5) { gc, _, _ in
                def.color.withAlphaComponent(0.2).setFill()
                gc.fill(CGRect(x: 0, y: 1, width: 7, height: 3))
                def.color.setFill()
                gc.fill(CGRect(x: 1, y: 2, width: 4, height: 1))
                gc.fill(CGRect(x: 2, y: 1, width: 3, height: 3))
                UIColor.white.setFill()
                gc.fill(CGRect(x: 5, y: 2, width: 2, height: 1))
            }

        case "shotgun":
            // Red pellet — small and round
            tex = renderPixelTexture(w: 4, h: 4) { gc, _, _ in
                def.color.withAlphaComponent(0.4).setFill()
                gc.fillEllipse(in: CGRect(x: 0, y: 0, width: 4, height: 4))
                def.color.setFill()
                gc.fill(CGRect(x: 1, y: 1, width: 2, height: 2))
            }

        case "smg":
            // Fast golden bullet — similar to pistol but with streak
            tex = renderPixelTexture(w: 5, h: 4) { gc, _, _ in
                def.color.withAlphaComponent(0.3).setFill()
                gc.fill(CGRect(x: 0, y: 1, width: 5, height: 2))
                def.color.setFill()
                gc.fill(CGRect(x: 1, y: 1, width: 3, height: 2))
                UIColor.white.withAlphaComponent(0.7).setFill()
                gc.fill(CGRect(x: 4, y: 1, width: 1, height: 2))
            }

        case "sniper":
            // Long white streak — ultra-fast tracer
            tex = renderPixelTexture(w: 10, h: 3) { gc, _, _ in
                UIColor.cyan.withAlphaComponent(0.15).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: 10, height: 3))
                UIColor.white.withAlphaComponent(0.5).setFill()
                gc.fill(CGRect(x: 0, y: 1, width: 8, height: 1))
                UIColor.white.setFill()
                gc.fill(CGRect(x: 5, y: 1, width: 5, height: 1))
                gc.fill(CGRect(x: 8, y: 0, width: 2, height: 3))
            }

        case "crossbow":
            // Brown arrow/bolt with pointed tip
            tex = renderPixelTexture(w: 8, h: 5) { gc, _, _ in
                def.color.setFill()
                gc.fill(CGRect(x: 0, y: 2, width: 6, height: 1))  // shaft
                gc.fill(CGRect(x: 0, y: 1, width: 1, height: 3))  // fletching
                UIColor(red: 0.5, green: 0.4, blue: 0.25, alpha: 1).setFill()
                gc.fill(CGRect(x: 1, y: 1, width: 1, height: 3))  // fletching 2
                UIColor(white: 0.7, alpha: 1).setFill()
                gc.fill(CGRect(x: 6, y: 2, width: 2, height: 1))  // tip
                gc.fill(CGRect(x: 7, y: 1, width: 1, height: 3))  // arrowhead
            }

        // ── EXPLOSIVE ───────────────────────────────────
        case "grenade":
            // Dark green sphere with ring/pin detail
            tex = renderPixelTexture(w: 6, h: 6) { gc, _, _ in
                def.color.withAlphaComponent(0.3).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: 6, height: 6))
                def.color.setFill()
                gc.fill(CGRect(x: 1, y: 1, width: 4, height: 4))
                UIColor(red: 0.15, green: 0.4, blue: 0.15, alpha: 1).setFill()
                gc.fill(CGRect(x: 2, y: 2, width: 2, height: 2))  // dark center
                UIColor(white: 0.6, alpha: 0.8).setFill()
                gc.fill(CGRect(x: 2, y: 0, width: 2, height: 1))  // pin
                gc.fill(CGRect(x: 4, y: 0, width: 1, height: 1))  // ring
            }

        case "rocket_launcher":
            // Orange rocket with tail fin and exhaust
            tex = renderPixelTexture(w: 10, h: 5) { gc, _, _ in
                // Body
                def.color.setFill()
                gc.fill(CGRect(x: 2, y: 1, width: 6, height: 3))
                // Nose cone — white
                UIColor.white.setFill()
                gc.fill(CGRect(x: 8, y: 2, width: 2, height: 1))
                gc.fill(CGRect(x: 7, y: 1, width: 2, height: 3))
                // Tail fins
                UIColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: 2, height: 1))
                gc.fill(CGRect(x: 0, y: 4, width: 2, height: 1))
                gc.fill(CGRect(x: 1, y: 1, width: 1, height: 3))
                // Exhaust glow
                UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 0.7).setFill()
                gc.fill(CGRect(x: 0, y: 2, width: 1, height: 1))
            }

        case "missile":
            // Large red missile with white nose, fins, bright exhaust
            tex = renderPixelTexture(w: 12, h: 6) { gc, _, _ in
                // Body
                def.color.setFill()
                gc.fill(CGRect(x: 3, y: 1, width: 7, height: 4))
                // Nose cone
                UIColor.white.setFill()
                gc.fill(CGRect(x: 10, y: 2, width: 2, height: 2))
                gc.fill(CGRect(x: 9, y: 1, width: 2, height: 4))
                // Tail fins
                UIColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: 3, height: 1))
                gc.fill(CGRect(x: 0, y: 5, width: 3, height: 1))
                gc.fill(CGRect(x: 1, y: 1, width: 2, height: 4))
                // Red stripe
                UIColor(red: 0.6, green: 0.1, blue: 0.05, alpha: 1).setFill()
                gc.fill(CGRect(x: 5, y: 2, width: 1, height: 2))
                // Exhaust
                UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 0.9).setFill()
                gc.fill(CGRect(x: 0, y: 2, width: 2, height: 2))
            }

        case "mortar":
            // Brown round shell with dark band
            tex = renderPixelTexture(w: 7, h: 7) { gc, _, _ in
                def.color.withAlphaComponent(0.3).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: 7, height: 7))
                def.color.setFill()
                gc.fill(CGRect(x: 1, y: 1, width: 5, height: 5))
                UIColor(red: 0.35, green: 0.25, blue: 0.12, alpha: 1).setFill()
                gc.fill(CGRect(x: 1, y: 3, width: 5, height: 1))  // dark band
                UIColor.white.withAlphaComponent(0.5).setFill()
                gc.fill(CGRect(x: 3, y: 1, width: 1, height: 1))  // highlight
            }

        case "plasma_cannon":
            // Glowing purple energy orb with ring
            tex = renderPixelTexture(w: 10, h: 10) { gc, _, _ in
                // Outer glow
                def.color.withAlphaComponent(0.15).setFill()
                gc.fillEllipse(in: CGRect(x: 0, y: 0, width: 10, height: 10))
                // Mid ring
                def.color.withAlphaComponent(0.4).setFill()
                gc.fillEllipse(in: CGRect(x: 1, y: 1, width: 8, height: 8))
                // Core
                def.color.setFill()
                gc.fill(CGRect(x: 3, y: 3, width: 4, height: 4))
                // Energy ring
                UIColor(red: 0.8, green: 0.5, blue: 1.0, alpha: 0.7).setFill()
                gc.fill(CGRect(x: 2, y: 4, width: 6, height: 2))
                gc.fill(CGRect(x: 4, y: 2, width: 2, height: 6))
                // Hot white center
                UIColor.white.withAlphaComponent(0.9).setFill()
                gc.fill(CGRect(x: 4, y: 4, width: 2, height: 2))
            }

        // ── SPECIAL ─────────────────────────────────────
        case "laser":
            // Bright cyan beam — elongated with pulsing core
            tex = renderPixelTexture(w: 8, h: 3) { gc, _, _ in
                UIColor.cyan.withAlphaComponent(0.2).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: 8, height: 3))
                UIColor.cyan.withAlphaComponent(0.6).setFill()
                gc.fill(CGRect(x: 0, y: 1, width: 8, height: 1))
                UIColor.white.setFill()
                gc.fill(CGRect(x: 2, y: 1, width: 4, height: 1))
                // Tip glow
                UIColor.cyan.setFill()
                gc.fill(CGRect(x: 7, y: 0, width: 1, height: 3))
            }

        case "flamethrower":
            // Orange-yellow flame particle
            tex = renderPixelTexture(w: 6, h: 6) { gc, _, _ in
                // Outer flame
                UIColor(red: 1, green: 0.3, blue: 0.0, alpha: 0.4).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: 6, height: 6))
                // Mid flame
                UIColor(red: 1, green: 0.5, blue: 0.0, alpha: 0.7).setFill()
                gc.fill(CGRect(x: 1, y: 1, width: 4, height: 4))
                // Core yellow
                UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.9).setFill()
                gc.fill(CGRect(x: 2, y: 2, width: 2, height: 2))
                // White hot tip
                UIColor.white.withAlphaComponent(0.7).setFill()
                gc.fill(CGRect(x: 3, y: 2, width: 1, height: 1))
            }

        case "poison_dart":
            // Small green dart with bright toxic tip
            tex = renderPixelTexture(w: 7, h: 3) { gc, _, _ in
                def.color.withAlphaComponent(0.3).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: 4, height: 3))
                def.color.setFill()
                gc.fill(CGRect(x: 1, y: 1, width: 4, height: 1))  // shaft
                UIColor(red: 0.1, green: 1.0, blue: 0.1, alpha: 1).setFill()
                gc.fill(CGRect(x: 5, y: 0, width: 2, height: 3))  // toxic tip
                gc.fill(CGRect(x: 6, y: 1, width: 1, height: 1))  // point
                UIColor(red: 0.2, green: 0.5, blue: 0.15, alpha: 0.8).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: 2, height: 1))  // fletching
                gc.fill(CGRect(x: 0, y: 2, width: 2, height: 1))
            }

        case "drone_strike":
            // Grey-white drone body with propeller dots
            tex = renderPixelTexture(w: 10, h: 8) { gc, _, _ in
                // Body
                UIColor(white: 0.85, alpha: 1).setFill()
                gc.fill(CGRect(x: 3, y: 3, width: 4, height: 2))
                // Wings
                UIColor(white: 0.7, alpha: 1).setFill()
                gc.fill(CGRect(x: 0, y: 2, width: 3, height: 1))
                gc.fill(CGRect(x: 7, y: 2, width: 3, height: 1))
                gc.fill(CGRect(x: 0, y: 5, width: 3, height: 1))
                gc.fill(CGRect(x: 7, y: 5, width: 3, height: 1))
                // Propellers (dots at wing tips)
                UIColor(white: 0.4, alpha: 0.8).setFill()
                gc.fill(CGRect(x: 0, y: 1, width: 2, height: 2))
                gc.fill(CGRect(x: 8, y: 1, width: 2, height: 2))
                gc.fill(CGRect(x: 0, y: 5, width: 2, height: 2))
                gc.fill(CGRect(x: 8, y: 5, width: 2, height: 2))
                // Camera/nose
                UIColor.red.withAlphaComponent(0.8).setFill()
                gc.fill(CGRect(x: 5, y: 4, width: 1, height: 1))
                // Tail exhaust
                UIColor(white: 0.5, alpha: 0.6).setFill()
                gc.fill(CGRect(x: 2, y: 3, width: 1, height: 2))
            }

        default:
            // Generic projectile fallback
            let px = max(def.projectileSize, 2)
            let cs = px + 2
            tex = renderPixelTexture(w: cs, h: cs) { gc, _, _ in
                def.color.withAlphaComponent(0.3).setFill()
                gc.fill(CGRect(x: 0, y: 0, width: cs, height: cs))
                def.color.setFill()
                gc.fill(CGRect(x: 1, y: 1, width: px, height: px))
                if px >= 3 {
                    UIColor.white.withAlphaComponent(0.85).setFill()
                    gc.fill(CGRect(x: cs / 2, y: cs / 2, width: 1, height: 1))
                }
            }
        }

        textureCache[def.id] = tex
        return tex
    }
}
