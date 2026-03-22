//
//  ProjectilePool.swift
//  Stars
//
//  Reusable pool for Projectile nodes.  Avoids frequent allocation of
//  short-lived SpriteKit nodes during combat.
//

import SpriteKit

final class ProjectilePool {

    static let shared = ProjectilePool()

    private var pool: [Projectile] = []
    private let maxPoolSize = 48  // increased for multi-pellet weapons

    /// Borrow a projectile from the pool, or create one if empty.
    func acquire(ownerID: String, damage: Int,
                 direction: CGVector, speed: CGFloat,
                 weaponID: String = "pistol",
                 homingTarget: Agent? = nil) -> Projectile {
        if let reused = pool.popLast() {
            reused.reconfigure(ownerID: ownerID, damage: damage,
                               direction: direction, speed: speed,
                               weaponID: weaponID,
                               homingTarget: homingTarget)
            return reused
        }
        return Projectile(ownerID: ownerID, damage: damage,
                          direction: direction, speed: speed,
                          weaponID: weaponID,
                          homingTarget: homingTarget)
    }

    /// Return a projectile to the pool instead of deallocating it.
    func recycle(_ projectile: Projectile) {
        guard !pool.contains(where: { $0 === projectile }) else { return }
        projectile.removeAllActions()
        projectile.removeFromParent()
        projectile.physicsBody?.velocity = .zero
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.none
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.none
        guard pool.count < maxPoolSize else { return }
        pool.append(projectile)
    }
}
