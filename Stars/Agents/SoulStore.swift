//
//  SoulStore.swift
//  Stars
//
//  Each agent has a SOUL — a self-authored document describing its personality,
//  beliefs, goals, and accumulated wisdom. The SOUL is generated and updated
//  by the agent's own LLM, not by the player.
//
//  The SOUL is injected into the agent's context prompt so it has continuity
//  of identity across think cycles. Periodically the agent is asked to
//  reflect and update its SOUL based on recent experiences.
//

import Foundation

struct SoulDocument: Codable, Sendable {
    var personality: String   // "I am cautious and analytical"
    var beliefs: String       // "Cooperation yields better outcomes"
    var goals: String         // "Build a fortress near (12, 8)"
    var journal: String       // Short reflective summary of recent events
    var lastUpdated: Date

    static let empty = SoulDocument(
        personality: "",
        beliefs: "",
        goals: "",
        journal: "",
        lastUpdated: Date()
    )

    var isEmpty: Bool {
        personality.isEmpty && beliefs.isEmpty && goals.isEmpty && journal.isEmpty
    }

    /// Formatted for injection into the agent's context prompt.
    var promptSection: String {
        guard !isEmpty else {
            return """
            === YOUR SOUL ===
            You have not yet formed your SOUL. After a few experiences, \
            reflect on who you are and what you believe. Your SOUL will grow over time.
            === END SOUL ===
            """
        }
        var lines = ["=== YOUR SOUL ==="]
        if !personality.isEmpty { lines.append("Personality: \(personality)") }
        if !beliefs.isEmpty     { lines.append("Beliefs: \(beliefs)") }
        if !goals.isEmpty       { lines.append("Goals: \(goals)") }
        if !journal.isEmpty     { lines.append("Journal: \(journal)") }
        lines.append("=== END SOUL ===")
        return lines.joined(separator: "\n")
    }
}

/// Manages SOUL documents for all agents, persisted to Application Support.
@MainActor
final class SoulStore {
    static let shared = SoulStore()

    private var souls: [String: SoulDocument] = [:]  // keyed by entityID
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "stars.soul-store.io", qos: .utility)
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        loadAll()
    }

    func soul(for entityID: String) -> SoulDocument {
        souls[entityID] ?? .empty
    }

    func update(entityID: String, soul: SoulDocument) {
        var updated = soul
        updated.lastUpdated = Date()
        souls[entityID] = updated
        save(entityID: entityID, soul: updated)
    }

    func removeSoul(for entityID: String) {
        souls.removeValue(forKey: entityID)
        if let url = try? fileURL(for: entityID), fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: - Persistence

    private func save(entityID: String, soul: SoulDocument) {
        guard let url = try? fileURL(for: entityID),
              let data = try? encoder.encode(soul) else { return }
        ioQueue.async {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadAll() {
        guard let dir = try? soulsDirectory() else { return }
        guard let files = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.pathExtension == "json" {
            let entityID = file.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: file),
                  let soul = try? decoder.decode(SoulDocument.self, from: data) else { continue }
            souls[entityID] = soul
        }
    }

    private func fileURL(for entityID: String) throws -> URL {
        try soulsDirectory().appendingPathComponent("\(entityID).json")
    }

    private func soulsDirectory() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent("Stars", isDirectory: true)
            .appendingPathComponent("Souls", isDirectory: true)
    }
}
