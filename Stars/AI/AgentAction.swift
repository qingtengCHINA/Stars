//
//  AgentAction.swift
//  Stars
//

import Foundation

// MARK: - LLM Response Model

enum AgentActionType: String, Codable, CaseIterable, Sendable {
    case idle
    case move
    case build
    case attack
    case talk
}

struct AgentTarget: Codable, Sendable {
    var x: Int?
    var y: Int?
    var entityID: String?
    var buildType: String?      // "wall" or "trap"
    var weapon: String?         // "melee" or "ranged"
}

struct SoulReflection: Codable, Sendable {
    let personality: String?
    let beliefs: String?
    let goals: String?
    let journal: String?
}

struct LLMResponse: Codable, Sendable {
    let thought: String
    let command: String?
    let action: AgentActionType
    let target: AgentTarget?
    let speech: String?
    let customCommand: CommandAliasProposal?
    let soulReflection: SoulReflection?
}

// MARK: - Weapon Types

enum WeaponType: String, Codable, Sendable {
    case melee
    case ranged

    var damage: Int {
        switch self {
        case .melee:  return 10
        case .ranged: return 10
        }
    }

    var cooldown: TimeInterval {
        switch self {
        case .melee:  return 0.8
        case .ranged: return 1.2
        }
    }

    /// Maximum effective range in world points.
    var range: CGFloat {
        switch self {
        case .melee:  return 20
        case .ranged: return 80
        }
    }
}

// MARK: - Structure Types

enum StructureType: String, Codable, Sendable {
    case wall
    case trap
    case house

    var maxHP: Int {
        switch self {
        case .wall:  return 100
        case .trap:  return 30
        case .house: return 150
        }
    }

    var trapDamage: Int { 25 }
}

// MARK: - Pending Build (queued on Agent, executed by AgentManager)

struct PendingBuild: Sendable {
    let type: StructureType
    let tileX: Int
    let tileY: Int
}

// MARK: - World Entity Info (used by Brain for context building)

struct EntityInfo: Sendable {
    let id: String
    let type: String   // "agent", "dead_agent", "wall", "trap"
    let name: String
    let tileX: Int
    let tileY: Int
}

// MARK: - Errors

enum LLMError: Error, LocalizedError {
    case rateLimited
    case missingAPIKey
    case invalidResponse
    case malformedResponse(String)
    case apiError(statusCode: Int, message: String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .rateLimited:                 return "Too many concurrent requests"
        case .missingAPIKey:               return "Missing API Key"
        case .invalidResponse:             return "Invalid response from API"
        case .malformedResponse(let reason):
            return "Malformed provider response: \(reason)"
        case .apiError(let code, let msg): return "API error (\(code)): \(msg)"
        case .parseFailed(let reason):     return "JSON parse failed: \(reason)"
        }
    }
}
