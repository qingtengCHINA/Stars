//
//  CombatSystem.swift
//  Stars
//
//  Handles all SKPhysicsContact events:
//    projectile → agent/structure   (ranged damage + AoE)
//    melee      → agent/structure   (melee damage)
//    trap       → agent             (trap damage + consume trap)
//
//  Full feedback loop:
//    - Victim knows WHO attacked them (attacker name + weapon)
//    - Attacker knows if attack landed and damage dealt
//    - Significant events auto-recorded to long-term memory
//    - Bounties auto-claimed on kills
//

import SpriteKit

final class CombatSystem {

    /// Set by GameScene to notify BuildSystem when structures take damage.
    var onStructureDamaged: (() -> Void)?

    /// Lookup agent by entityID — set by GameScene to enable attacker attribution.
    var agentLookup: ((String) -> Agent?)?

    /// Lookup ALL agents — set by GameScene for AoE damage.
    var allAgentsProvider: (() -> [Agent])?

    /// Check if an agent is sheltered inside their own house — set by GameScene.
    var isAgentSheltered: ((Agent) -> Bool)?

    /// Call from `SKScene.didBegin(_:)`.
    func handleContact(_ contact: SKPhysicsContact) {
        let (a, b) = ordered(contact.bodyA, contact.bodyB)

        let catA = a.categoryBitMask
        let catB = b.categoryBitMask

        // ── Projectile hits ──

        if catB == PhysicsCategory.projectile {
            guard let proj = b.node as? Projectile else { return }
            let weaponDef = WeaponCatalog.weapon(for: proj.weaponID)
            let weaponLabel = weaponDef.displayName

            if catA == PhysicsCategory.agent, let victim = a.node as? Agent {
                guard victim.entityID != proj.ownerID else { return } // no self-damage

                // House defense: sheltered agents block non-explosive attacks
                if weaponDef.category != .explosive && isAgentSheltered?(victim) == true {
                    victim.memory.record(type: .combat, content: "Attack blocked — I'm sheltered inside my house! Only explosives can reach me here.")
                    if let attacker = agentLookup?(proj.ownerID) {
                        attacker.memory.record(type: .combat, content: "\(victim.displayName) is sheltered inside a house. My \(weaponLabel) was blocked. Use explosive weapons to damage sheltered agents.")
                    }
                    ProjectilePool.shared.recycle(proj)
                    return
                }

                let attacker = agentLookup?(proj.ownerID)
                let attackerName = attacker?.displayName ?? "unknown"

                // AoE explosion
                if weaponDef.aoeRadius > 0 {
                    handleAoE(at: proj.position, radius: weaponDef.aoeRadius,
                              damage: weaponDef.damage, attackerID: proj.ownerID,
                              attacker: attacker, weaponLabel: weaponLabel,
                              color: weaponDef.color, parent: proj.parent)
                    ProjectilePool.shared.recycle(proj)
                    return
                }

                // Single-target hit
                let wasDead = victim.isDead
                let hpBefore = victim.hp
                victim.takeDamage(proj.damage)
                let actualDamage = hpBefore - victim.hp

                victim.memory.record(type: .combat, content: "\(attackerName) hit me with \(weaponLabel) for \(actualDamage) damage (HP: \(victim.hp)/\(victim.maxHP))")

                if let attacker {
                    let killMsg = (victim.isDead && !wasDead) ? " — KILLED \(victim.displayName)!" : ""
                    attacker.memory.record(type: .combat, content: "My \(weaponLabel) hit \(victim.displayName) for \(actualDamage) damage (target HP: \(victim.hp)/\(victim.maxHP))\(killMsg)")
                }

                recordKillOrCritical(
                    attacker: attacker, victim: victim,
                    attackerName: attackerName, weaponLabel: weaponLabel,
                    wasDead: wasDead
                )

                ProjectilePool.shared.recycle(proj)
                return
            }

            if catA == PhysicsCategory.structure, let structure = a.node as? Structure {
                // Homing projectile hitting a wall → wall absorbs hit, no AoE
                if proj.isHoming {
                    let hpBefore = structure.hp
                    structure.takeDamage(structure.hp) // destroy the wall entirely
                    let actualDamage = hpBefore
                    onStructureDamaged?()

                    if let attacker = agentLookup?(proj.ownerID) {
                        attacker.memory.record(type: .combat, content: "My homing \(weaponLabel) was blocked by a \(structure.structureType.rawValue)! Wall destroyed, but target is safe. Use positioning to avoid walls.")
                    }

                    IncrementalArchiveStore.shared.recordStructure(structure, reason: "homing-wall-block")
                    WorldEventLogStore.shared.append(
                        category: .combat,
                        entityID: structure.entityID,
                        title: NSLocalizedString("log.structure_damaged", comment: ""),
                        message: "Homing \(weaponLabel) blocked by \(structure.structureType.rawValue) (destroyed, \(actualDamage) dmg)"
                    )
                    ProjectilePool.shared.recycle(proj)
                    return
                }

                // AoE explosion on structure hit
                if weaponDef.aoeRadius > 0 {
                    handleAoE(at: proj.position, radius: weaponDef.aoeRadius,
                              damage: weaponDef.damage, attackerID: proj.ownerID,
                              attacker: agentLookup?(proj.ownerID),
                              weaponLabel: weaponLabel,
                              color: weaponDef.color, parent: proj.parent)
                    // Also damage the structure
                    structure.takeDamage(proj.damage)
                    onStructureDamaged?()
                    ProjectilePool.shared.recycle(proj)
                    return
                }

                let hpBefore = structure.hp
                structure.takeDamage(proj.damage)
                let actualDamage = hpBefore - structure.hp
                onStructureDamaged?()

                if let attacker = agentLookup?(proj.ownerID) {
                    let destroyed = structure.hp <= 0
                    attacker.memory.record(type: .combat, content: "My \(weaponLabel) hit a \(structure.structureType.rawValue) for \(actualDamage) damage\(destroyed ? " — DESTROYED!" : " (remaining HP: \(structure.hp)/\(structure.maxHP))")")
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

            let weaponID = meleeNode.userData?["weaponID"] as? String ?? "fist"
            let weaponLabel = WeaponCatalog.weapon(for: weaponID).displayName

            if catA == PhysicsCategory.agent, let victim = a.node as? Agent {
                guard victim.entityID != ownerID else { return }

                // House defense: sheltered agents block melee attacks
                // (landmine/claymore AoE melee can still damage)
                let weaponDefMelee = WeaponCatalog.weapon(for: weaponID)
                if weaponDefMelee.aoeRadius == 0 && isAgentSheltered?(victim) == true {
                    victim.memory.record(type: .combat, content: "Melee attack blocked — I'm inside my house!")
                    if let attacker = agentLookup?(ownerID) {
                        attacker.memory.record(type: .combat, content: "\(victim.displayName) is sheltered inside a house. Melee blocked. Use explosives!")
                    }
                    return
                }

                let attacker = agentLookup?(ownerID)
                let attackerName = attacker?.displayName ?? "unknown"
                let wasDead = victim.isDead
                let hpBefore = victim.hp
                victim.takeDamage(damage)
                let actualDamage = hpBefore - victim.hp

                victim.memory.record(type: .combat, content: "\(attackerName) hit me with \(weaponLabel) for \(actualDamage) damage (HP: \(victim.hp)/\(victim.maxHP))")

                if let attacker {
                    let killMsg = (victim.isDead && !wasDead) ? " — KILLED \(victim.displayName)!" : ""
                    attacker.memory.record(type: .combat, content: "My \(weaponLabel) hit \(victim.displayName) for \(actualDamage) damage (target HP: \(victim.hp)/\(victim.maxHP))\(killMsg)")
                }

                recordKillOrCritical(
                    attacker: attacker, victim: victim,
                    attackerName: attackerName, weaponLabel: weaponLabel,
                    wasDead: wasDead
                )
                return
            }

            if catA == PhysicsCategory.structure, let structure = a.node as? Structure {
                let hpBefore = structure.hp
                structure.takeDamage(damage)
                let actualDamage = hpBefore - structure.hp
                onStructureDamaged?()

                if let attacker = agentLookup?(ownerID) {
                    let destroyed = structure.hp <= 0
                    attacker.memory.record(type: .combat, content: "My \(weaponLabel) hit a \(structure.structureType.rawValue) for \(actualDamage) damage\(destroyed ? " — DESTROYED!" : " (remaining HP: \(structure.hp)/\(structure.maxHP))")")
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

    // MARK: - AoE Damage

    /// Deals damage to all agents within radius of the explosion point.
    private func handleAoE(at center: CGPoint, radius: CGFloat, damage: Int,
                           attackerID: String, attacker: Agent?,
                           weaponLabel: String, color: UIColor,
                           parent: SKNode?) {
        // Visual explosion
        if let parent {
            WeaponSystem.spawnExplosion(at: center, radius: radius, color: color, in: parent)
        }

        let attackerName = attacker?.displayName ?? "unknown"

        // Damage all agents in radius
        guard let allAgents = allAgentsProvider?() else { return }
        for victim in allAgents {
            guard victim.entityID != attackerID else { continue } // no self-damage
            guard !victim.isDead else { continue }
            let dist = hypot(victim.position.x - center.x, victim.position.y - center.y)
            guard dist <= radius else { continue }

            let wasDead = victim.isDead
            let hpBefore = victim.hp
            victim.takeDamage(damage)
            let actualDamage = hpBefore - victim.hp

            victim.memory.record(type: .combat, content: "\(attackerName)'s \(weaponLabel) explosion hit me for \(actualDamage) damage (HP: \(victim.hp)/\(victim.maxHP))")

            if let attacker {
                let killMsg = (victim.isDead && !wasDead) ? " — KILLED \(victim.displayName)!" : ""
                attacker.memory.record(type: .combat, content: "\(weaponLabel) explosion hit \(victim.displayName) for \(actualDamage) damage\(killMsg)")
            }

            recordKillOrCritical(
                attacker: attacker, victim: victim,
                attackerName: attackerName, weaponLabel: weaponLabel,
                wasDead: wasDead
            )
        }
    }

    // MARK: - Shared Kill / Critical Recording

    private func recordKillOrCritical(
        attacker: Agent?, victim: Agent,
        attackerName: String, weaponLabel: String,
        wasDead: Bool
    ) {
        if victim.isDead && !wasDead {
            if let attacker {
                let victimStars = victim.stars
                let reward = max(EconomyConfig.shared.killReward, victimStars * EconomyConfig.shared.killRewardPercent / 100)
                attacker.awardKillReward(victimStars: victimStars)
                attacker.brain?.recordSignificantEvent()
                LongTermMemory.shared.recordCombatEvent(
                    entityID: attacker.entityID,
                    content: "Killed \(victim.displayName) with \(weaponLabel). Looted \(reward)⭐ (victim had \(victimStars)⭐)! (Total: \(attacker.stars))"
                )

                // Bounty claim
                let bountyReward = BountyBoard.shared.claimBounties(
                    killerID: attacker.entityID,
                    killerAgent: attacker,
                    victimID: victim.entityID
                )
                if bountyReward > 0 {
                    attacker.brain?.recordSignificantEvent()
                }
            }
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
