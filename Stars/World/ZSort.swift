//
//  ZSort.swift
//  Stars
//
//  Depth-sorting for top-down 2D rendering.
//
//  In a top-down view, objects with lower y (closer to the bottom of the
//  screen / closer to the camera) should render in front of objects with
//  higher y.  SpriteKit renders higher zPosition on top, so:
//
//      zPosition = entityBase - position.y * epsilon
//
//  All entities (agents + structures) share the same z-range so they
//  can properly occlude each other.  Projectiles live above this range.
//

import CoreGraphics

enum ZSort {
    /// Base z for terrain chunks.
    static let terrain: CGFloat = 0

    /// Base z for all entities (agents + structures).
    /// The y-offset keeps them within the range ~(5 ... 15).
    static let entityBase: CGFloat = 10

    /// Base z for projectiles & melee hitboxes (always above entities).
    static let projectile: CGFloat = 20

    /// Very small factor so y-offset stays within ±5 of entityBase
    /// for reasonable world coordinates (±50 000 pt).
    private static let epsilon: CGFloat = 0.0001

    /// Compute the z-position for an entity at the given world y-coordinate.
    static func depthZ(for worldY: CGFloat) -> CGFloat {
        entityBase - worldY * epsilon
    }
}
