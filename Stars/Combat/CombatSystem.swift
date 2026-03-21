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
                let attacker = agentLookup?(proj.ownerID)
                let attackerName = attacker?.displayName ?? "unknown"
                let wasDead = victim.isDead
                let hpBefore = victim.hp
                victim.takeDamage(proj.damage)
                let actualDamage = hpBefore - victim.hp

                // === Victim feedback: knows WHO attacked ===
                victim.memory.record(type: .combat, content: "\(attackerName) hit me with a ranged attack for \(actualDamage) damage (HP: \(victim.hp)/\(victim.maxHP))")

                // === Attacker feedback: knows hit landed ===
                if let attacker {
                    let killMsg = (victim.isDead && !wasDead) ? " — KILLED \(victim.displayName)!" : ""
                    attacker.memory.record(type: .combat, content: "My ranged attack hit \(victim.displayName) for \(actualDamage) damage (target HP: \(victim.hp)/\(victim.maxHP))\(killMsg)")
                }

                recordKillOrCritical(
                    attacker: attacker, victim: victim,
                    attackerName: attackerName, weaponLabel: "ranged attack",
                    wasDead: wasDead
                )

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
                let attacker = agentLookup?(ownerID)
                let attackerName = attacker?.displayName ?? "unknown"
                let wasDead = victim.isDead
                let hpBefore = victim.hp
                victim.takeDamage(damage)
                let actualDamage = hpBefore - victim.hp

                // === Victim feedback: knows WHO attacked ===
                victim.memory.record(type: .combat, content: "\(attackerName) hit me with a melee attack for \(actualDamage) damage (HP: \(victim.hp)/\(victim.maxHP))")

                // === Attacker feedback: knows hit landed ===
                if let attacker {
                    let killMsg = (victim.isDead && !wasDead) ? " — KILLED \(victim.displayName)!" : ""
                    attacker.memory.record(type: .combat, content: "My melee attack hit \(victim.displayName) for \(actualDamage) damage (target HP: \(victim.hp)/\(victim.maxHP))\(killMsg)")
                }

                recordKillOrCritical(
                    attacker: attacker, victim: victim,
                    attackerName: attackerName, weaponLabel: "melee attack",
                    wasDead: wasDead
                )
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
                    recordKillOrCritical(
                        attacker: nil, victim: victim,
                        attackerName: "a trap at (\(trapTileX), \(trapTileY))",
                        weaponLabel: "trap", wasDead: wasDead
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

    // MARK: - Shared Kill / Critical Recording

    /// Unified handler for kill, death, and critical-wound recording.
    /// Eliminates copy-paste across ranged / melee / trap hit blocks.
    private func recordKillOrCritical(
        attacker: Agent?, victim: Agent,
        attackerName: String, weaponLabel: String,
        wasDead: Bool
    ) {
        if victim.isDead && !wasDead {
            // Attacker side
            if let attacker {
                attacker.awardStar()
                attacker.brain?.recordSignificantEvent()
                LongTermMemory.shared.recordCombatEvent(
                    entityID: attacker.entityID,
                    content: "Killed \(victim.displayName) with \(weaponLabel). Earned a Star! (Total: \(attacker.stars))"
                )
            }
            // Victim side
            victim.brain?.recordSignificantEvent()
            LongTermMemory.shared.recordCombatEvent(
                entityID: victim.entityID,
                content: "Killed by \(attackerName)'s \(weaponLabel). HP reached 0."
            )
        } else if !victim.isDead && Double(victim.hp) / Double(victim.maxHP) < 0.3 {
            LongTermMemory.shared.recordCombatEvent(
                entityID: victim.entityID,
                content: "Critically wounded by \(attackerName)'s \(weaponLabel) — HP at \(victim.hp)/\(victim.maxHP)."
            )
        }
    }

    // Sort bodies so catA <= catB for deterministic matching.
    private func ordered(_ a: SKPhysicsBody,
                         _ b: SKPhysicsBody) -> (SKPhysicsBody, SKPhysicsBody) {
        a.categoryBitMask <= b.categoryBitMask ? (a, b) : (b, a)
    }
}
