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
    private let maxPoolSize = 32

    /// Borrow a projectile from the pool, or create one if empty.
    func acquire(ownerID: String, damage: Int,
                 direction: CGVector, speed: CGFloat) -> Projectile {
        if let reused = pool.popLast() {
            reused.reconfigure(ownerID: ownerID, damage: damage,
                               direction: direction, speed: speed)
            return reused
        }
        return Projectile(ownerID: ownerID, damage: damage,
                          direction: direction, speed: speed)
    }

    /// Return a projectile to the pool instead of deallocating it.
    func recycle(_ projectile: Projectile) {
        projectile.removeAllActions()
        projectile.removeFromParent()
        projectile.physicsBody?.velocity = .zero
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.none
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.none
        guard pool.count < maxPoolSize else { return }
        pool.append(projectile)
    }
}
