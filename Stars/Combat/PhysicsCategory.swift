//
//  PhysicsCategory.swift
//  Stars
//
//  Central bitmask definitions for the SpriteKit physics engine.
//
//  Collision matrix (what physically blocks what):
//    Agent  ←→  Structure   (agents can't walk through walls)
//
//  Contact matrix (what triggers damage callbacks):
//    Projectile  →  Agent, Structure
//    Melee       →  Agent, Structure
//    Trap        →  Agent
//

import Foundation

struct PhysicsCategory {
    static let none:       UInt32 = 0
    static let agent:      UInt32 = 1 << 0   // 1
    static let structure:  UInt32 = 1 << 1   // 2
    static let projectile: UInt32 = 1 << 2   // 4
    static let melee:      UInt32 = 1 << 3   // 8
    static let trap:       UInt32 = 1 << 4   // 16
}
