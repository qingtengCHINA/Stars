//
//  CombatSystem.swift
//  Stars
//
//  Handles all SKPhysicsContact events:
//    projectile → agent/structure   (ranged damage)
//    melee      → agent/structure   (melee damage)
//    trap       → agent             (trap damage + consume trap)
//
//  Full feedback loop:
//    - Victim knows WHO attacked them (attacker name)
//    - Attacker knows if attack landed and damage dealt
//    - Significant events auto-recorded to long-term memory
//

import SpriteKit

final class CombatSystem {

    /// Set by GameScene to notify BuildSystem when structures take damage.
    var onStructureDamaged: (() -> Void)?

    /// Lookup agent by entityID — set by GameScene to enable attacker attribution.
    var agentLookup: ((String) -> Agent?)?

    /// Call from `SKScene.didBegin(_:)`.
    func handleContact(_ contact: SKPhysicsContact) {
        let (a, b) = ordered(contact.bodyA, contact.bodyB)

        let catA = a.categoryBitMask
        let catB = b.categoryBitMask

        // ── Projectile hits ──

        if catB == PhysicsCategory.projectile {
            guard let proj = b.node as? Projectile else { return }

            if catA == PhysicsCategory.agent, let victim = a.node as? Agent {
                guard victim.entityID != proj.ownerID else { return } // no self-damage
                let attackerName = agentLookup?(proj.ownerID)?.displayName ?? "unknown"
                let wasDead = victim.isDead
                let hpBefore = victim.hp
                victim.takeDamage(proj.damage)
                let actualDamage = hpBefore - victim.hp

                // === Victim feedback: knows WHO attacked ===
                victim.memory.record(type: .combat, content: "\(attackerName) hit me with a ranged attack for \(actualDamage) damage (HP: \(victim.hp)/\(victim.maxHP))")

                // === Attacker feedback: knows hit landed ===
                if let attacker = agentLookup?(proj.ownerID) {
                    let killMsg = (victim.isDead && !wasDead) ? " — KILLED \(victim.displayName)!" : ""
                    attacker.memory.record(type: .combat, content: "My ranged attack hit \(victim.displayName) for \(actualDamage) damage (target HP: \(victim.hp)/\(victim.maxHP))\(killMsg)")

                    if victim.isDead && !wasDead {
                        attacker.awardStar()
                        LongTermMemory.shared.recordCombatEvent(
                            entityID: attacker.entityID,
                            content: "Killed \(victim.displayName) with a ranged attack. Earned a Star! (Total: \(attacker.stars))"
                        )
                    }
                }

                // Record significant damage to victim's long-term memory
                if victim.isDead && !wasDead {
                    LongTermMemory.shared.recordCombatEvent(
                        entityID: victim.entityID,
                        content: "Killed by \(attackerName)'s ranged attack. HP reached 0."
                    )
                } else if Double(victim.hp) / Double(victim.maxHP) < 0.3 {
                    LongTermMemory.shared.recordCombatEvent(
                        entityID: victim.entityID,
                        content: "Critically wounded by \(attackerName)'s ranged attack — HP at \(victim.hp)/\(victim.maxHP). Must be careful."
                    )
                }

                ProjectilePool.shared.recycle(proj)
                return
            }

            if catA == PhysicsCategory.structure, let structure = a.node as? Structure {
                let hpBefore = structure.hp
                structure.takeDamage(proj.damage)
                let actualDamage = hpBefore - structure.hp
                onStructureDamaged?()

                // Attacker feedback for structure hits
                if let attacker = agentLookup?(proj.ownerID) {
                    let destroyed = structure.hp <= 0
                    attacker.memory.record(type: .combat, content: "My ranged attack hit a \(structure.structureType.rawValue) for \(actualDamage) damage\(destroyed ? " — DESTROYED!" : " (remaining HP: \(structure.hp)/\(structure.maxHP))")")
                }

                IncrementalArchiveStore.shared.recordStructure(structure, reason: "projectile-hit")
                WorldEventLogStore.shared.append(
                    category: .combat,
                    entityID: structure.entityID,
                    title: NSLocalizedString("log.structure_damaged", comment: ""),
                    message: String(format: NSLocalizedString("log.structure_hit_ranged", comment: ""), structure.structureType.rawValue, structure.hp, structure.maxHP)
                )
                ProjectilePool.shared.recycle(proj)
                return
            }
        }

        // ── Melee hits ──

        if catB == PhysicsCategory.melee {
            guard let meleeNode = b.node,
                  let ownerID = meleeNode.userData?["ownerID"] as? String,
                  let damage  = meleeNode.userData?["damage"]  as? Int
            else { return }

            if catA == PhysicsCategory.agent, let victim = a.node as? Agent {
                guard victim.entityID != ownerID else { return }
                let attackerName = agentLookup?(ownerID)?.displayName ?? "unknown"
                let wasDead = victim.isDead
                let hpBefore = victim.hp
                victim.takeDamage(damage)
                let actualDamage = hpBefore - victim.hp

                // === Victim feedback: knows WHO attacked ===
                victim.memory.record(type: .combat, content: "\(attackerName) hit me with a melee attack for \(actualDamage) damage (HP: \(victim.hp)/\(victim.maxHP))")

                // === Attacker feedback: knows hit landed ===
                if let attacker = agentLookup?(ownerID) {
                    let killMsg = (victim.isDead && !wasDead) ? " — KILLED \(victim.displayName)!" : ""
                    attacker.memory.record(type: .combat, content: "My melee attack hit \(victim.displayName) for \(actualDamage) damage (target HP: \(victim.hp)/\(victim.maxHP))\(killMsg)")

                    if victim.isDead && !wasDead {
                        attacker.awardStar()
                        LongTermMemory.shared.recordCombatEvent(
                            entityID: attacker.entityID,
                            content: "Killed \(victim.displayName) with a melee attack. Earned a Star! (Total: \(attacker.stars))"
                        )
                    }
                }

                // Record kill/critical to victim's long-term memory
                if victim.isDead && !wasDead {
                    LongTermMemory.shared.recordCombatEvent(
                        entityID: victim.entityID,
                        content: "Killed by \(attackerName)'s melee attack. HP reached 0."
                    )
                } else if Double(victim.hp) / Double(victim.maxHP) < 0.3 {
                    LongTermMemory.shared.recordCombatEvent(
                        entityID: victim.entityID,
                        content: "Critically wounded by \(attackerName)'s melee — HP at \(victim.hp)/\(victim.maxHP). Self-defense or retreat needed."
                    )
                }
                return
            }

            if catA == PhysicsCategory.structure, let structure = a.node as? Structure {
                let hpBefore = structure.hp
                structure.takeDamage(damage)
                let actualDamage = hpBefore - structure.hp
                onStructureDamaged?()

                // Attacker feedback for structure hits
                if let attacker = agentLookup?(ownerID) {
                    let destroyed = structure.hp <= 0
                    attacker.memory.record(type: .combat, content: "My melee attack hit a \(structure.structureType.rawValue) for \(actualDamage) damage\(destroyed ? " — DESTROYED!" : " (remaining HP: \(structure.hp)/\(structure.maxHP))")")
                }

                IncrementalArchiveStore.shared.recordStructure(structure, reason: "melee-hit")
                WorldEventLogStore.shared.append(
                    category: .combat,
                    entityID: structure.entityID,
                    title: NSLocalizedString("log.structure_damaged", comment: ""),
                    message: String(format: NSLocalizedString("log.structure_hit_melee", comment: ""), structure.structureType.rawValue, structure.hp, structure.maxHP)
                )
                return
            }
        }

        // ── Trap contact ──

        if catA == PhysicsCategory.agent && catB == PhysicsCategory.trap {
            if let victim = a.node as? Agent, let trap = b.node as? Structure {
                let wasDead = victim.isDead
                let hpBefore = victim.hp
                victim.takeDamage(StructureType.trap.trapDamage)
                let actualDamage = hpBefore - victim.hp

                let trapTileX = Int(floor(trap.position.x / Chunk.tileSize))
                let trapTileY = Int(floor(trap.position.y / Chunk.tileSize))

                victim.memory.record(type: .combat, content: "Stepped on a trap at (\(trapTileX), \(trapTileY))! Took \(actualDamage) damage (HP: \(victim.hp)/\(victim.maxHP))")

                // Traps are always worth remembering
                LongTermMemory.shared.recordCombatEvent(
                    entityID: victim.entityID,
                    content: "Stepped on trap at (\(trapTileX), \(trapTileY)). Took \(actualDamage) damage. Watch for traps in this area!"
                )

                if victim.isDead && !wasDead {
                    LongTermMemory.shared.recordCombatEvent(
                        entityID: victim.entityID,
                        content: "Killed by a trap at (\(trapTileX), \(trapTileY)). HP reached 0."
                    )
                }

                trap.takeDamage(trap.hp) // consume the trap
                onStructureDamaged?()
                IncrementalArchiveStore.shared.recordStructure(trap, reason: "trap-consumed")
                WorldEventLogStore.shared.append(
                    category: .combat,
                    entityID: victim.entityID,
                    title: NSLocalizedString("log.trap_triggered", comment: ""),
                    message: String(format: NSLocalizedString("log.trap_triggered_msg", comment: ""), trap.structureType.rawValue, actualDamage)
                )
            }
            return
        }
    }

    // Sort bodies so catA <= catB for deterministic matching.
    private func ordered(_ a: SKPhysicsBody,
                         _ b: SKPhysicsBody) -> (SKPhysicsBody, SKPhysicsBody) {
        a.categoryBitMask <= b.categoryBitMask ? (a, b) : (b, a)
    }
}
