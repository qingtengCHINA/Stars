//
//  WeaponCatalog.swift
//  Stars
//
//  Defines all 22 weapons in the Stars world.
//  Agents start with fist + pistol for free.
//  Other weapons are purchased with Stars via /buy_weapon.
//

import UIKit

// MARK: - Weapon Definition

struct WeaponDefinition: Sendable {
    let id: String
    let displayName: String
    let category: WeaponCategory
    let damage: Int
    let cooldown: TimeInterval
    let cost: Int           // Stars to purchase (0 = free)
    let reach: CGFloat      // melee hitbox offset / ranged max range (world pts)
    let speed: CGFloat      // projectile speed (ranged only)
    let aoeRadius: CGFloat  // 0 = single target
    let pellets: Int        // >1 = multi-projectile (shotgun, flamethrower)
    let spreadAngle: CGFloat // degrees spread for multi-pellet
    let color: UIColor      // projectile / hitbox flash color
    let projectileSize: Int // pixel size for projectile texture

    enum WeaponCategory: String, Sendable {
        case melee
        case ranged
        case explosive  // ranged + AoE on impact
    }
}

// MARK: - Catalog

enum WeaponCatalog {

    /// All 22 weapon definitions, keyed by weapon ID.
    static let all: [String: WeaponDefinition] = {
        var map = [String: WeaponDefinition]()
        for w in weapons { map[w.id] = w }
        return map
    }()

    /// Lookup a weapon by ID; falls back to fist if unknown.
    static func weapon(for id: String) -> WeaponDefinition {
        all[id] ?? all["fist"]!
    }

    /// Returns which WeaponType category the weapon belongs to (for physics).
    static func physicsCategory(for id: String) -> WeaponType {
        let w = weapon(for: id)
        return w.category == .melee ? .melee : .ranged
    }

    /// All weapons sorted by category then cost.
    static let weapons: [WeaponDefinition] = [

        // ══════════════════════════════════════
        // MELEE (5) — close-range hitbox attacks
        // ══════════════════════════════════════

        WeaponDefinition(
            id: "fist", displayName: "Fist / 拳头",
            category: .melee, damage: 8, cooldown: 0.6, cost: 0,
            reach: 14, speed: 0, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: .white, projectileSize: 0
        ),
        WeaponDefinition(
            id: "sword", displayName: "Sword / 剑",
            category: .melee, damage: 15, cooldown: 0.8, cost: 3,
            reach: 18, speed: 0, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1), projectileSize: 0
        ),
        WeaponDefinition(
            id: "axe", displayName: "Axe / 斧头",
            category: .melee, damage: 22, cooldown: 1.2, cost: 5,
            reach: 14, speed: 0, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1), projectileSize: 0
        ),
        WeaponDefinition(
            id: "spear", displayName: "Spear / 长矛",
            category: .melee, damage: 12, cooldown: 0.9, cost: 4,
            reach: 24, speed: 0, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.7, green: 0.55, blue: 0.35, alpha: 1), projectileSize: 0
        ),
        WeaponDefinition(
            id: "chainsaw", displayName: "Chainsaw / 电锯",
            category: .melee, damage: 28, cooldown: 1.5, cost: 8,
            reach: 16, speed: 0, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1), projectileSize: 0
        ),

        // ══════════════════════════════════════
        // RANGED (6) — single-target projectiles
        // ══════════════════════════════════════

        WeaponDefinition(
            id: "pistol", displayName: "Pistol / 手枪",
            category: .ranged, damage: 8, cooldown: 0.8, cost: 0,
            reach: 80, speed: 120, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 1), projectileSize: 2
        ),
        WeaponDefinition(
            id: "rifle", displayName: "Rifle / 步枪",
            category: .ranged, damage: 15, cooldown: 1.0, cost: 5,
            reach: 130, speed: 160, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1), projectileSize: 3
        ),
        WeaponDefinition(
            id: "shotgun", displayName: "Shotgun / 霰弹枪",
            category: .ranged, damage: 7, cooldown: 1.5, cost: 6,
            reach: 50, speed: 100, aoeRadius: 0, pellets: 5, spreadAngle: 30,
            color: UIColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1), projectileSize: 2
        ),
        WeaponDefinition(
            id: "smg", displayName: "SMG / 冲锋枪",
            category: .ranged, damage: 6, cooldown: 0.25, cost: 4,
            reach: 80, speed: 140, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1), projectileSize: 2
        ),
        WeaponDefinition(
            id: "sniper", displayName: "Sniper / 狙击枪",
            category: .ranged, damage: 35, cooldown: 2.5, cost: 10,
            reach: 220, speed: 250, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: .white, projectileSize: 3
        ),
        WeaponDefinition(
            id: "crossbow", displayName: "Crossbow / 弩",
            category: .ranged, damage: 12, cooldown: 1.2, cost: 3,
            reach: 100, speed: 90, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.6, green: 0.45, blue: 0.25, alpha: 1), projectileSize: 3
        ),

        // ══════════════════════════════════════
        // EXPLOSIVE (5) — ranged with AoE blast
        // ══════════════════════════════════════

        WeaponDefinition(
            id: "grenade", displayName: "Grenade / 手雷",
            category: .explosive, damage: 20, cooldown: 3.0, cost: 5,
            reach: 60, speed: 80, aoeRadius: 30, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1), projectileSize: 3
        ),
        WeaponDefinition(
            id: "rocket_launcher", displayName: "Rocket / 火箭弹",
            category: .explosive, damage: 25, cooldown: 3.0, cost: 10,
            reach: 130, speed: 100, aoeRadius: 35, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1), projectileSize: 4
        ),
        WeaponDefinition(
            id: "missile", displayName: "Missile / 导弹",
            category: .explosive, damage: 40, cooldown: 5.0, cost: 18,
            reach: 180, speed: 130, aoeRadius: 45, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 1), projectileSize: 5
        ),
        WeaponDefinition(
            id: "mortar", displayName: "Mortar / 迫击炮",
            category: .explosive, damage: 30, cooldown: 4.0, cost: 12,
            reach: 160, speed: 70, aoeRadius: 45, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1), projectileSize: 4
        ),
        WeaponDefinition(
            id: "plasma_cannon", displayName: "Plasma Cannon / 等离子炮",
            category: .explosive, damage: 45, cooldown: 4.0, cost: 22,
            reach: 140, speed: 90, aoeRadius: 40, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 1), projectileSize: 5
        ),

        // ══════════════════════════════════════
        // SPECIAL (6) — unique mechanics
        // ══════════════════════════════════════

        WeaponDefinition(
            id: "laser", displayName: "Laser / 激光枪",
            category: .ranged, damage: 20, cooldown: 0.5, cost: 15,
            reach: 180, speed: 350, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: .cyan, projectileSize: 2
        ),
        WeaponDefinition(
            id: "flamethrower", displayName: "Flamethrower / 火焰喷射器",
            category: .ranged, damage: 6, cooldown: 0.5, cost: 8,
            reach: 45, speed: 60, aoeRadius: 0, pellets: 3, spreadAngle: 25,
            color: UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1), projectileSize: 3
        ),
        WeaponDefinition(
            id: "poison_dart", displayName: "Poison Dart / 毒镖",
            category: .ranged, damage: 18, cooldown: 2.0, cost: 4,
            reach: 90, speed: 110, aoeRadius: 0, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.3, green: 0.85, blue: 0.2, alpha: 1), projectileSize: 2
        ),
        WeaponDefinition(
            id: "landmine", displayName: "Landmine / 地雷",
            category: .melee, damage: 35, cooldown: 2.0, cost: 5,
            reach: 14, speed: 0, aoeRadius: 25, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1), projectileSize: 0
        ),
        WeaponDefinition(
            id: "claymore", displayName: "Claymore / 阔剑地雷",
            category: .melee, damage: 25, cooldown: 2.0, cost: 4,
            reach: 14, speed: 0, aoeRadius: 20, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.3, green: 0.35, blue: 0.3, alpha: 1), projectileSize: 0
        ),
        WeaponDefinition(
            id: "drone_strike", displayName: "Drone Strike / 无人机打击",
            category: .explosive, damage: 50, cooldown: 10.0, cost: 25,
            reach: 250, speed: 200, aoeRadius: 50, pellets: 1, spreadAngle: 0,
            color: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), projectileSize: 4
        ),
    ]

    // MARK: - Prompt Helpers

    /// Weapons shop section for agent prompt — shows what's available to buy.
    /// Weapons can be purchased multiple times to stock ammo.
    static func shopPromptSection(ownedWeapons: Set<String>, currentStars: Int) -> String {
        let available = weapons.filter { $0.cost > 0 }
        guard !available.isEmpty else { return "" }

        let affordable = available.filter { currentStars >= $0.cost }
        let shown: [WeaponDefinition]
        if affordable.isEmpty {
            shown = Array(available.sorted { $0.cost < $1.cost }.prefix(5))
        } else {
            shown = Array(affordable.prefix(8))
        }

        var lines = ["Weapon Shop (/buy_weapon — can rebuy for more ammo):"]
        for w in shown {
            let tag = currentStars >= w.cost ? "✅" : "❌"
            let aoe = w.aoeRadius > 0 ? ",AoE" : ""
            let multi = w.pellets > 1 ? ",×\(w.pellets)" : ""
            let homing = w.isHoming ? ",🎯homing" : ""
            lines.append("  \(tag) \(w.id): \(w.cost)⭐ \(w.damage)dmg CD\(String(format: "%.1f", w.cooldown))s ×\(w.ammoPerPurchase)ammo\(aoe)\(multi)\(homing)")
        }
        if available.count > shown.count {
            lines.append("  ... and \(available.count - shown.count) more weapons available")
        }
        return lines.joined(separator: "\n")
    }

    /// Inventory section for agent prompt — shows owned weapons with ammo count.
    static func inventoryPromptSection(ownedWeapons: Set<String>, weaponAmmo: [String: Int]) -> String {
        let owned = weapons.filter { ownedWeapons.contains($0.id) }
        guard !owned.isEmpty else { return "" }
        var lines = ["Your weapons:"]
        for w in owned {
            let cat = w.category.rawValue
            let aoe = w.aoeRadius > 0 ? ", AoE" : ""
            let multi = w.pellets > 1 ? ", ×\(w.pellets)" : ""
            let homing = w.isHoming ? ", 🎯homing" : ""
            let ammo: String
            if WeaponCatalog.defaultWeapons.contains(w.id) {
                ammo = "∞"
            } else {
                ammo = "\(weaponAmmo[w.id] ?? 0)"
            }
            lines.append("  - \(w.id) [\(cat)] \(w.damage)dmg, CD\(String(format: "%.1f", w.cooldown))s, ammo:\(ammo)\(aoe)\(multi)\(homing)")
        }
        return lines.joined(separator: "\n")
    }

    /// Free weapons every agent starts with (unlimited ammo).
    static let defaultWeapons: Set<String> = ["fist", "pistol"]
}

// MARK: - Ammo & Homing (computed from weapon stats, no struct changes needed)

extension WeaponDefinition {

    /// How many uses one purchase gives. 0 = unlimited (free weapons).
    var ammoPerPurchase: Int {
        switch id {
        // Free — unlimited
        case "fist", "pistol":          return 0
        // Melee
        case "sword":                   return 12
        case "axe":                     return 8
        case "spear":                   return 10
        case "chainsaw":               return 6
        // Ranged
        case "rifle":                   return 15
        case "shotgun":                return 10
        case "smg":                     return 20
        case "sniper":                  return 8
        case "crossbow":               return 12
        // Explosive
        case "grenade":                return 5
        case "rocket_launcher":        return 4
        case "missile":                return 3
        case "mortar":                 return 4
        case "plasma_cannon":          return 3
        // Special
        case "laser":                  return 10
        case "flamethrower":           return 8
        case "poison_dart":            return 8
        case "landmine":               return 3
        case "claymore":               return 3
        case "drone_strike":           return 2
        default:                       return 5
        }
    }

    /// Tracking projectile — guaranteed hit (unless target hides behind a wall).
    var isHoming: Bool {
        ["missile", "rocket_launcher", "drone_strike"].contains(id)
    }
}
