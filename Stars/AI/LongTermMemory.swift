//
//  LongTermMemory.swift
//  Stars
//
//  Persistent knowledge store per agent. Survives ring-buffer compaction.
//  Supports importance-based and keyword-relevance-based retrieval.
//
//  Short-term MemoryStore → compaction → distill here.
//  CombatSystem / ActionResolver → direct recording of significant events.
//

import Foundation

struct KnowledgeEntry: Codable, Sendable, Identifiable {
    let id: UUID
    let category: KnowledgeCategory
    var content: String
    let createdAt: Date
    var lastRecalled: Date
    var importance: Int  // 1–5
    var recallCount: Int // how many times this was injected into a prompt

    init(category: KnowledgeCategory, content: String, importance: Int = 3) {
        self.id = UUID()
        self.category = category
        self.content = content
        self.createdAt = Date()
        self.lastRecalled = Date()
        self.importance = max(1, min(5, importance))
        self.recallCount = 0
    }

    // Backward compatibility: existing JSON files may not have recallCount
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        category = try container.decode(KnowledgeCategory.self, forKey: .category)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastRecalled = try container.decode(Date.self, forKey: .lastRecalled)
        importance = try container.decode(Int.self, forKey: .importance)
        recallCount = try container.decodeIfPresent(Int.self, forKey: .recallCount) ?? 0
    }
}

enum KnowledgeCategory: String, Codable, Sendable, CaseIterable {
    case fact       // "Agent X is aggressive"
    case strategy   // "Building walls near water is effective"
    case event      // "I was killed by Agent Y on Day 3"
    case social     // "Agent Z is my ally"
    case location   // "There's a good defensible position at (20, 15)"
}

@MainActor
final class LongTermMemory {
    static let shared = LongTermMemory()

    private var stores: [String: [KnowledgeEntry]] = [:]  // keyed by entityID
    private let maxEntriesPerAgent = 50
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "stars.longterm-memory.io", qos: .utility)
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
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

    // MARK: - Read (Importance-based)

    func entries(for entityID: String) -> [KnowledgeEntry] {
        stores[entityID] ?? []
    }

    /// Returns the most important entries for prompt injection.
    func topEntries(for entityID: String, count: Int = 8) -> [KnowledgeEntry] {
        let all = entries(for: entityID)
        return Array(all.sorted { $0.importance > $1.importance }.prefix(count))
    }

    // MARK: - Read (Keyword Relevance)

    /// Search for entries relevant to a context string.
    /// Scores by keyword overlap + importance + recency. Updates recall tracking.
    func relevantEntries(for entityID: String, context: String, count: Int = 6) -> [KnowledgeEntry] {
        var all = stores[entityID] ?? []
        guard !all.isEmpty else { return [] }

        let contextKeywords = extractKeywords(from: context)
        guard !contextKeywords.isEmpty else {
            return topEntries(for: entityID, count: count)
        }

        let now = Date()
        let scored: [(Int, Double)] = all.enumerated().map { (idx, entry) in
            let entryWords = Set(
                entry.content.lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count > 2 }
            )
            let overlap = contextKeywords.filter { entryWords.contains($0) }.count
            let daysSinceRecall = max(0, now.timeIntervalSince(entry.lastRecalled) / 86400)
            let recencyBonus = max(0, 3.0 - daysSinceRecall * 0.5)
            let score = Double(overlap * 3 + entry.importance * 2) + recencyBonus
            return (idx, score)
        }

        let topIndices = scored
            .sorted { $0.1 > $1.1 }
            .prefix(count)
            .map { $0.0 }

        // Update recall tracking
        for idx in topIndices {
            all[idx].lastRecalled = now
            all[idx].recallCount += 1
        }
        stores[entityID] = all
        // Defer save to avoid frequent I/O
        saveDirty.insert(entityID)

        return topIndices.map { all[$0] }
    }

    private var saveDirty: Set<String> = []

    /// Flush pending saves. Call periodically (e.g., on autosave).
    func flushPendingSaves() {
        for entityID in saveDirty {
            save(entityID: entityID)
        }
        saveDirty.removeAll()
    }

    /// Formatted section for agent prompts — uses importance-based retrieval.
    func promptSection(for entityID: String) -> String {
        let top = topEntries(for: entityID, count: 8)
        guard !top.isEmpty else { return "" }

        var lines = ["Long-term knowledge (persistent memories that survive compaction):"]
        for entry in top {
            lines.append("  - [\(entry.category.rawValue)] \(entry.content)")
        }
        return lines.joined(separator: "\n")
    }

    /// Contextual section — keyword-relevant retrieval based on current situation.
    func contextualSection(for entityID: String, context: String) -> String {
        let relevant = relevantEntries(for: entityID, context: context, count: 5)
        guard !relevant.isEmpty else { return "" }

        var lines = ["Relevant recalled memories (triggered by current situation):"]
        for entry in relevant {
            lines.append("  - [\(entry.category.rawValue)] \(entry.content)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Write

    func record(entityID: String, category: KnowledgeCategory, content: String, importance: Int = 3) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var agentEntries = stores[entityID] ?? []

        // Deduplicate: if a similar entry exists, merge/update it
        if let existingIdx = agentEntries.firstIndex(where: { similar($0.content, trimmed) }) {
            // Update with newer content if longer/more detailed
            if trimmed.count > agentEntries[existingIdx].content.count {
                agentEntries[existingIdx].content = trimmed
            }
            agentEntries[existingIdx].lastRecalled = Date()
            agentEntries[existingIdx].importance = max(agentEntries[existingIdx].importance, importance)
        } else {
            agentEntries.append(KnowledgeEntry(category: category, content: trimmed, importance: importance))
        }

        // Evict lowest-importance entries if over limit
        if agentEntries.count > maxEntriesPerAgent {
            agentEntries.sort { $0.importance > $1.importance }
            agentEntries = Array(agentEntries.prefix(maxEntriesPerAgent))
        }

        stores[entityID] = agentEntries
        save(entityID: entityID)
    }

    /// Record a high-importance combat event (death, kill, significant damage).
    func recordCombatEvent(entityID: String, content: String) {
        record(entityID: entityID, category: .event, content: content, importance: 4)
    }

    /// Record a social observation about another agent.
    func recordSocialFact(entityID: String, content: String) {
        record(entityID: entityID, category: .social, content: content, importance: 3)
    }

    func removeAll(for entityID: String) {
        stores.removeValue(forKey: entityID)
        if let url = try? fileURL(for: entityID), fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: - Distillation

    func distill(entityID: String, compactedSummary: String, category: KnowledgeCategory = .event) {
        let trimmed = compactedSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        record(entityID: entityID, category: category, content: trimmed, importance: 2)
    }

    // MARK: - Keyword Extraction

    private static let stopWords: Set<String> = [
        "the", "a", "an", "is", "at", "in", "to", "of", "and", "or", "for",
        "i", "my", "you", "your", "it", "its", "this", "that", "was", "with",
        "not", "no", "but", "are", "be", "has", "have", "had", "do", "does",
        "did", "will", "would", "can", "could", "from", "on", "by", "as",
        "me", "he", "she", "they", "them", "we", "our", "his", "her",
        "null", "tile", "tiles", "nearby", "agent", "current", "position",
    ]

    private func extractKeywords(from text: String) -> Set<String> {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !Self.stopWords.contains($0) }
        return Set(words)
    }

    // MARK: - Similarity Check

    private func similar(_ a: String, _ b: String) -> Bool {
        let la = a.lowercased()
        let lb = b.lowercased()

        // Exact match
        if la == lb { return true }

        // Prefix match (first 50 chars)
        let prefixLen = 50
        if la.prefix(prefixLen) == lb.prefix(prefixLen) { return true }

        // Jaccard similarity on words
        let wordsA = Set(la.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 })
        let wordsB = Set(lb.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 })
        guard !wordsA.isEmpty, !wordsB.isEmpty else { return false }
        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count
        return Double(intersection) / Double(union) > 0.7
    }

    // MARK: - Persistence

    private func save(entityID: String) {
        guard let entries = stores[entityID],
              let url = try? fileURL(for: entityID),
              let data = try? encoder.encode(entries) else { return }
        ioQueue.async {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadAll() {
        guard let dir = try? knowledgeDirectory() else { return }
        guard let files = try? fileManager.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.pathExtension == "json" {
            let entityID = file.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: file),
                  let entries = try? decoder.decode([KnowledgeEntry].self, from: data) else { continue }
            stores[entityID] = entries
        }
    }

    private func fileURL(for entityID: String) throws -> URL {
        try knowledgeDirectory().appendingPathComponent("\(entityID).json")
    }

    private func knowledgeDirectory() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent("Stars", isDirectory: true)
            .appendingPathComponent("Knowledge", isDirectory: true)
    }
}
