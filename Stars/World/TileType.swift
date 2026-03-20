//
//  TileType.swift
//  Stars
//

import UIKit

enum TileType: Int, CaseIterable, Codable, Sendable {
    case deepWater
    case water
    case sand
    case grass
    case darkGrass
    case flowers
    case dirt
    case stone

    var color: UIColor {
        switch self {
        case .deepWater: return UIColor(red: 0.08, green: 0.18, blue: 0.30, alpha: 1)
        case .water:     return UIColor(red: 0.18, green: 0.34, blue: 0.50, alpha: 1)
        case .sand:      return UIColor(red: 0.72, green: 0.64, blue: 0.43, alpha: 1)
        case .grass:     return UIColor(red: 0.35, green: 0.61, blue: 0.31, alpha: 1)
        case .darkGrass: return UIColor(red: 0.24, green: 0.45, blue: 0.23, alpha: 1)
        case .flowers:   return UIColor(red: 0.78, green: 0.53, blue: 0.48, alpha: 1)
        case .dirt:      return UIColor(red: 0.48, green: 0.37, blue: 0.25, alpha: 1)
        case .stone:     return UIColor(red: 0.42, green: 0.44, blue: 0.46, alpha: 1)
        }
    }
}
