//
//  WeaponSystem.swift
//  Stars
//
//  Stateless factory for melee hitboxes and ranged projectiles.
//

import SpriteKit

enum WeaponSystem {

    // MARK: - Melee

    /// Spawns a short-lived hitbox in front of the agent's facing direction.
    static func meleeAttack(by agent: Agent, in parent: SKNode) {
        let hitboxSize = CGSize(width: 14, height: 14)
        let offset: CGFloat = 14

        let hitbox = SKSpriteNode(color: .clear, size: hitboxSize)
        hitbox.position = CGPoint(
            x: agent.position.x + cos(agent.facingAngle) * offset,
            y: agent.position.y + sin(agent.facingAngle) * offset
        )
        hitbox.zPosition = ZSort.projectile
        hitbox.name = "melee"

        // Owner info for damage attribution
        let info = NSMutableDictionary()
        info["ownerID"] = agent.entityID
        info["damage"]  = WeaponType.melee.damage
        hitbox.userData = info

        // Physics — static sensor
        let body = SKPhysicsBody(rectangleOf: hitboxSize)
        body.isDynamic = false
        body.categoryBitMask    = PhysicsCategory.melee
        body.contactTestBitMask = PhysicsCategory.agent | PhysicsCategory.structure
        body.collisionBitMask   = PhysicsCategory.none
        hitbox.physicsBody = body

        // Visual slash flash
        let flash = SKSpriteNode(
            color: UIColor.white.withAlphaComponent(0.6),
            size: hitboxSize
        )
        hitbox.addChild(flash)

        parent.addChild(hitbox)

        // Remove after one physics tick
        hitbox.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.removeFromParent(),
        ]))
    }

    // MARK: - Ranged

    /// Fires a projectile from the agent toward the target world position.
    static func rangedAttack(by agent: Agent, toward target: CGPoint, in parent: SKNode) {
        let dx = target.x - agent.position.x
        let dy = target.y - agent.position.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return }

        let direction = CGVector(dx: dx / dist, dy: dy / dist)
        let projectile = ProjectilePool.shared.acquire(
            ownerID: agent.entityID,
            damage: WeaponType.ranged.damage,
            direction: direction,
            speed: 120
        )
        // Spawn slightly in front of the agent so it doesn't self-collide
        projectile.position = CGPoint(
            x: agent.position.x + direction.dx * (Agent.agentSize / 2 + 3),
            y: agent.position.y + direction.dy * (Agent.agentSize / 2 + 3)
        )
        parent.addChild(projectile)
    }
}
