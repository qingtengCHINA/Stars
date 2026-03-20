//
//  MemoryStore.swift
//  Stars
//
//  Per-agent memory store. Records important events and provides
//  both recency-based and keyword-based retrieval for LLM context.
//

import Foundation

// MARK: - Memory Entry

struct MemoryEntry: Codable, Sendable {
    let timestamp: TimeInterval   // game time
    let type: MemoryEventType
    let content: String
}

enum MemoryEventType: String, Codable, CaseIterable, Sendable {
    case combat     // took damage, attacked someone, killed/died
    case build      // placed a wall or trap
    case move       // moved to a location
    case talk       // said something or heard something
    case observe    // noticed something nearby
}

// MARK: - Short-Term Message (dialogue broadcast)

struct ShortTermMessage: Codable, Sendable {
    let speakerName: String
    let content: String
    let gameTick: TimeInterval
}

struct MemoryCompactionResult: Sendable {
    let compactedEntryCount: Int
    let summary: String
}

// MARK: - Memory Store

/// In-memory ring buffer of agent events, accessed from MainActor only.
/// Supports both recency-based and keyword-based retrieval.
@MainActor
final class MemoryStore {

    private var entries: [MemoryEntry] = []
    private let maxEntries: Int = 80

    // MARK: - Record

    func record(type: MemoryEventType, content: String, gameTime: TimeInterval = 0) {
        let entry = MemoryEntry(timestamp: gameTime, type: type, content: content)
        entries.append(entry)

        // Evict oldest when exceeding capacity
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    // MARK: - Query (Recency)

    /// Returns the most recent `count` memories, oldest first.
    func recentEntries(count: Int = 5) -> [MemoryEntry] {
        let start = max(0, entries.count - count)
        return Array(entries[start...])
    }

    func allEntries() -> [MemoryEntry] {
        entries
    }

    // MARK: - Query (Keyword Search)

    /// Search memories by keywords. Returns matches sorted by recency (newest first).
    /// Used for contextual recall — "what do I know about X?"
    func searchEntries(keywords: [String], limit: Int = 6) -> [MemoryEntry] {
        guard !keywords.isEmpty else { return [] }
        let lowKeywords = keywords.map { $0.lowercased() }

        let matches = entries.enumerated().compactMap { (index, entry) -> (MemoryEntry, Int)? in
            let text = entry.content.lowercased()
            let matchCount = lowKeywords.filter { text.contains($0) }.count
            guard matchCount > 0 else { return nil }
            return (entry, index * 100 + matchCount * 1000) // recency + relevance
        }

        return matches
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    /// Search by memory type. Returns most recent entries of that type.
    func entriesOfType(_ type: MemoryEventType, limit: Int = 5) -> [MemoryEntry] {
        entries.filter { $0.type == type }.suffix(limit).reversed()
    }

    // MARK: - Restore

    func restore(entries: [MemoryEntry]) {
        self.entries = Array(entries.suffix(maxEntries))
    }

    // MARK: - Compaction

    func compactOlderEntries(keepingRecent recentCount: Int = 8) -> MemoryCompactionResult? {
        guard entries.count > recentCount + 2 else { return nil }

        let compactCount = entries.count - recentCount
        let olderEntries = Array(entries.prefix(compactCount))
        let newerEntries = Array(entries.suffix(recentCount))

        var grouped: [MemoryEventType: [String]] = [:]
        for entry in olderEntries {
            grouped[entry.type, default: []].append(entry.content)
        }

        let summary = MemoryEventType.allCases
            .compactMap { type -> String? in
                guard let values = grouped[type], !values.isEmpty else { return nil }
                let preview = values.suffix(3).joined(separator: " | ")
                return "[\(type.rawValue)] \(values.count)条: \(preview)"
            }
            .joined(separator: " ; ")

        guard !summary.isEmpty else { return nil }

        entries = [
            MemoryEntry(
                timestamp: olderEntries.first?.timestamp ?? 0,
                type: .observe,
                content: "Compacted \(compactCount) older memories: \(summary)"
            )
        ] + newerEntries

        return MemoryCompactionResult(compactedEntryCount: compactCount, summary: summary)
    }

    /// Total number of recorded memories.
    var totalCount: Int { entries.count }
}
