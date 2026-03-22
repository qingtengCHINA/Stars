//
//  WeaponSystem.swift
//  Stars
//
//  Stateless factory for melee hitboxes and ranged projectiles.
//  Supports all 22 weapons from WeaponCatalog with unique animations.
//

import SpriteKit

enum WeaponSystem {

    // MARK: - Melee

    /// Spawns a short-lived circular hitbox centered on the agent.
    /// All enemies within reach radius take damage.
    static func meleeAttack(by agent: Agent, weaponDef: WeaponDefinition, in parent: SKNode) {
        let diameter = weaponDef.reach * 2
        let hitbox = SKSpriteNode(color: .clear, size: CGSize(width: diameter, height: diameter))
        // Centered on agent — circular area of effect
        hitbox.position = agent.position
        hitbox.zPosition = ZSort.projectile
        hitbox.name = "melee"

        // Owner info for damage attribution
        let info = NSMutableDictionary()
        info["ownerID"] = agent.entityID
        info["damage"]  = weaponDef.damage
        info["weaponID"] = weaponDef.id
        hitbox.userData = info

        // Physics — circular sensor centered on agent
        let body = SKPhysicsBody(circleOfRadius: weaponDef.reach)
        body.isDynamic = false
        body.categoryBitMask    = PhysicsCategory.melee
        body.contactTestBitMask = PhysicsCategory.agent | PhysicsCategory.structure
        body.collisionBitMask   = PhysicsCategory.none
        hitbox.physicsBody = body

        // Weapon-specific melee visual
        addMeleeVisual(to: hitbox, weaponDef: weaponDef, angle: agent.facingAngle)

        parent.addChild(hitbox)

        // Remove after one physics tick
        hitbox.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.12),
            SKAction.removeFromParent(),
        ]))
    }

    /// Creates weapon-specific melee slash visuals.
    private static func addMeleeVisual(to hitbox: SKSpriteNode, weaponDef: WeaponDefinition, angle: CGFloat) {
        let reach = weaponDef.reach

        switch weaponDef.id {
        case "sword":
            // Arc slash — curved line
            let arc = SKShapeNode()
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: reach * 0.8,
                        startAngle: angle - 0.6, endAngle: angle + 0.6, clockwise: false)
            arc.path = path
            arc.strokeColor = weaponDef.color.withAlphaComponent(0.9)
            arc.lineWidth = 2
            arc.glowWidth = 1
            arc.fillColor = .clear
            hitbox.addChild(arc)
            arc.run(SKAction.fadeAlpha(to: 0, duration: 0.1))

        case "axe":
            // Heavy impact — thick short arc + shake flash
            let impact = SKSpriteNode(color: weaponDef.color.withAlphaComponent(0.8),
                                      size: CGSize(width: reach * 1.2, height: reach * 0.6))
            impact.zRotation = angle
            hitbox.addChild(impact)
            impact.run(SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.05),
                SKAction.fadeAlpha(to: 0, duration: 0.07),
            ]))

        case "spear":
            // Thrust line — elongated forward
            let thrust = SKSpriteNode(color: weaponDef.color.withAlphaComponent(0.8),
                                      size: CGSize(width: reach * 1.5, height: 2))
            thrust.zRotation = angle
            hitbox.addChild(thrust)
            thrust.run(SKAction.fadeAlpha(to: 0, duration: 0.1))

        case "chainsaw":
            // Rapid flicker — multiple flashing rectangles
            for i in 0..<3 {
                let spark = SKSpriteNode(color: weaponDef.color.withAlphaComponent(0.9),
                                         size: CGSize(width: 3, height: 2))
                spark.position = CGPoint(
                    x: CGFloat.random(in: -reach/2...reach/2),
                    y: CGFloat.random(in: -reach/2...reach/2)
                )
                hitbox.addChild(spark)
                spark.run(SKAction.sequence([
                    SKAction.wait(forDuration: Double(i) * 0.03),
                    SKAction.fadeAlpha(to: 0, duration: 0.06),
                ]))
            }

        case "landmine", "claymore":
            // AoE melee — expanding ring
            if weaponDef.aoeRadius > 0 {
                spawnExplosion(at: hitbox.position, radius: weaponDef.aoeRadius,
                               color: weaponDef.color, in: hitbox.parent ?? hitbox)
            }

        default:
            // Fist / generic — simple flash
            let flash = SKSpriteNode(
                color: weaponDef.color.withAlphaComponent(0.7),
                size: CGSize(width: reach, height: reach)
            )
            hitbox.addChild(flash)
            flash.run(SKAction.fadeAlpha(to: 0, duration: 0.08))
        }
    }

    // MARK: - Ranged

    /// Fires projectile(s) from the agent toward the target using weapon-specific stats.
    /// For homing weapons, the projectile tracks `homingTarget` until contact.
    static func rangedAttack(by agent: Agent, toward target: CGPoint,
                             weaponDef: WeaponDefinition, in parent: SKNode,
                             homingTarget: Agent? = nil) {
        let dx = target.x - agent.position.x
        let dy = target.y - agent.position.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return }

        let baseAngle = atan2(dy, dx)

        // Muzzle flash
        spawnMuzzleFlash(at: agent.position, angle: baseAngle,
                          color: weaponDef.color, in: parent)

        // Fire multiple pellets for shotgun/flamethrower-type weapons
        let count = max(1, weaponDef.pellets)
        let spreadRad = weaponDef.spreadAngle * .pi / 180

        for i in 0..<count {
            let angle: CGFloat
            if count == 1 {
                angle = baseAngle
            } else {
                let offset = spreadRad * (CGFloat(i) / CGFloat(count - 1) - 0.5)
                angle = baseAngle + offset
            }

            let direction = CGVector(dx: cos(angle), dy: sin(angle))
            let projectile = ProjectilePool.shared.acquire(
                ownerID: agent.entityID,
                damage: weaponDef.damage,
                direction: direction,
                speed: weaponDef.speed,
                weaponID: weaponDef.id,
                homingTarget: homingTarget
            )
            // Spawn slightly in front of the agent
            projectile.position = CGPoint(
                x: agent.position.x + direction.dx * (Agent.agentSize / 2 + 3),
                y: agent.position.y + direction.dy * (Agent.agentSize / 2 + 3)
            )
            parent.addChild(projectile)
        }
    }

    // MARK: - Muzzle Flash

    /// Small directional flash at projectile origin.
    private static func spawnMuzzleFlash(at position: CGPoint, angle: CGFloat,
                                          color: UIColor, in parent: SKNode) {
        let flash = SKSpriteNode(color: color.withAlphaComponent(0.9),
                                  size: CGSize(width: 4, height: 3))
        flash.position = CGPoint(
            x: position.x + cos(angle) * (Agent.agentSize / 2 + 2),
            y: position.y + sin(angle) * (Agent.agentSize / 2 + 2)
        )
        flash.zRotation = angle
        flash.zPosition = ZSort.projectile + 1
        parent.addChild(flash)

        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.06),
                SKAction.fadeAlpha(to: 0, duration: 0.08),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    // MARK: - AoE Explosion Visual

    /// Creates a multi-layered pixel explosion effect at a position.
    static func spawnExplosion(at position: CGPoint, radius: CGFloat,
                               color: UIColor, in parent: SKNode) {
        // Inner bright core
        let core = SKShapeNode(circleOfRadius: 3)
        core.fillColor = UIColor.white.withAlphaComponent(0.9)
        core.strokeColor = .clear
        core.position = position
        core.zPosition = ZSort.projectile + 2
        parent.addChild(core)

        core.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: radius / 6, duration: 0.1),
                SKAction.fadeAlpha(to: 0, duration: 0.15),
            ]),
            SKAction.removeFromParent(),
        ]))

        // Mid ring — weapon color
        let ring = SKShapeNode(circleOfRadius: 2)
        ring.fillColor = color.withAlphaComponent(0.6)
        ring.strokeColor = color.withAlphaComponent(0.8)
        ring.lineWidth = 1.5
        ring.position = position
        ring.zPosition = ZSort.projectile + 1
        parent.addChild(ring)

        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: radius / 3, duration: 0.2),
                SKAction.fadeAlpha(to: 0, duration: 0.3),
            ]),
            SKAction.removeFromParent(),
        ]))

        // Outer shockwave ring
        let shockwave = SKShapeNode(circleOfRadius: 1)
        shockwave.fillColor = .clear
        shockwave.strokeColor = color.withAlphaComponent(0.4)
        shockwave.lineWidth = 1
        shockwave.position = position
        shockwave.zPosition = ZSort.projectile
        parent.addChild(shockwave)

        shockwave.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: radius / 1.5, duration: 0.35),
                SKAction.fadeAlpha(to: 0, duration: 0.4),
            ]),
            SKAction.removeFromParent(),
        ]))

        // Debris particles — small colored squares scattered outward
        let particleCount = min(Int(radius / 5), 8)
        for _ in 0..<particleCount {
            let debris = SKSpriteNode(color: color.withAlphaComponent(0.8),
                                       size: CGSize(width: 2, height: 2))
            debris.position = position
            debris.zPosition = ZSort.projectile + 1
            parent.addChild(debris)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: radius * 0.3...radius * 0.9)
            let dest = CGPoint(x: position.x + cos(angle) * dist,
                               y: position.y + sin(angle) * dist)

            debris.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(to: dest, duration: TimeInterval.random(in: 0.15...0.3)),
                    SKAction.fadeAlpha(to: 0, duration: 0.3),
                    SKAction.scale(to: 0.3, duration: 0.3),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
    }
}
