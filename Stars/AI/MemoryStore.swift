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
    /// Structured extracts from compacted memories, for long-term distillation.
    let extracts: [CompactionExtract]
    /// The last significant entry before compaction — used as a continuity bridge.
    let bridgeContext: String?
}

/// A structured piece of knowledge extracted during compaction,
/// ready to be distilled into LongTermMemory with proper category & importance.
struct CompactionExtract: Sendable {
    let category: KnowledgeCategory
    let content: String
    let importance: Int  // 1–5
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

    /// Narrative-aware compaction: preserves temporal flow, extracts structured
    /// knowledge for long-term distillation, and generates a continuity bridge.
    ///
    /// Inspired by memsearch (episode-based grouping) and OpenClaw (priority-
    /// based memory preservation).  The result carries `extracts` for
    /// LongTermMemory distillation and a `bridgeContext` for continuity.
    func compactOlderEntries(keepingRecent recentCount: Int = 8) -> MemoryCompactionResult? {
        guard entries.count > recentCount + 2 else { return nil }

        let compactCount = entries.count - recentCount
        let olderEntries = Array(entries.prefix(compactCount))
        let newerEntries = Array(entries.suffix(recentCount))

        // ── 1. Build narrative timeline (preserve temporal order) ──

        let episodes = buildEpisodes(from: olderEntries)
        let narrativeParts = episodes.map { episode -> String in
            let typeLabel = episode.dominantType.rawValue
            if episode.entries.count == 1 {
                return "[\(typeLabel)] \(episode.entries[0].content)"
            }
            // Summarize multi-entry episodes: first + last + count
            let first = episode.entries.first!.content
            let last = episode.entries.last!.content
            if episode.entries.count == 2 {
                return "[\(typeLabel)] \(first) → \(last)"
            }
            return "[\(typeLabel) ×\(episode.entries.count)] \(first) → … → \(last)"
        }
        let summary = narrativeParts.joined(separator: " ; ")
        guard !summary.isEmpty else { return nil }

        // ── 2. Extract structured knowledge for long-term distillation ──

        var extracts = [CompactionExtract]()
        for entry in olderEntries {
            if let extract = classifyForDistillation(entry) {
                extracts.append(extract)
            }
        }

        // ── 3. Build continuity bridge (what was the agent doing/pursuing?) ──

        let bridgeContext = buildBridgeContext(from: olderEntries, into: newerEntries)

        // ── 4. Replace old entries with compacted summary + bridge ──

        var compactedEntries = [MemoryEntry]()

        // The compacted narrative
        compactedEntries.append(MemoryEntry(
            timestamp: olderEntries.first?.timestamp ?? 0,
            type: .observe,
            content: "Earlier memories (\(compactCount) events): \(String(summary.prefix(500)))"
        ))

        // Bridge entry connecting past → present
        if let bridge = bridgeContext {
            compactedEntries.append(MemoryEntry(
                timestamp: olderEntries.last?.timestamp ?? 0,
                type: .observe,
                content: bridge
            ))
        }

        entries = compactedEntries + newerEntries

        return MemoryCompactionResult(
            compactedEntryCount: compactCount,
            summary: summary,
            extracts: extracts,
            bridgeContext: bridgeContext
        )
    }

    // MARK: - Episode Builder

    /// An episode is a consecutive run of related events (same type or tightly
    /// interleaved).  This groups the flat memory list into meaningful chunks,
    /// inspired by memsearch's heading-aware chunking.
    private struct Episode {
        var entries: [MemoryEntry]
        var dominantType: MemoryEventType

        init(first: MemoryEntry) {
            entries = [first]
            dominantType = first.type
        }

        mutating func append(_ entry: MemoryEntry) {
            entries.append(entry)
            // Update dominant type by majority
            var counts: [MemoryEventType: Int] = [:]
            for e in entries { counts[e.type, default: 0] += 1 }
            if let top = counts.max(by: { $0.value < $1.value }) {
                dominantType = top.key
            }
        }
    }

    private func buildEpisodes(from entries: [MemoryEntry]) -> [Episode] {
        guard let first = entries.first else { return [] }
        var episodes = [Episode(first: first)]

        for entry in entries.dropFirst() {
            let current = episodes[episodes.count - 1]
            // Continue episode if same type or closely related (combat+talk often interleave)
            let related = entry.type == current.dominantType
                || (entry.type == .talk && current.dominantType == .combat)
                || (entry.type == .combat && current.dominantType == .talk)
                || current.entries.count < 3 // small episodes absorb anything
            if related {
                episodes[episodes.count - 1].append(entry)
            } else {
                episodes.append(Episode(first: entry))
            }
        }
        return episodes
    }

    // MARK: - Knowledge Extraction for Distillation

    /// Classify a memory entry into a structured extract for LongTermMemory.
    /// High-importance events (combat, social) are extracted; low-value
    /// entries (routine movement) are skipped.
    private func classifyForDistillation(_ entry: MemoryEntry) -> CompactionExtract? {
        let content = entry.content

        switch entry.type {
        case .combat:
            // Deaths and kills are critical (importance 4-5)
            let isKill = content.lowercased().contains("kill") || content.contains("击杀")
            let isDeath = content.lowercased().contains("died") || content.lowercased().contains("dead") || content.contains("死亡")
            if isKill || isDeath {
                return CompactionExtract(category: .event, content: content, importance: 5)
            }
            return CompactionExtract(category: .event, content: content, importance: 3)

        case .talk:
            // Social interactions: alliances, treaties, threats
            let isSocial = content.contains("ally") || content.contains("treaty") || content.contains("盟")
                || content.contains("challenge") || content.contains("warn") || content.contains("挑战")
            if isSocial {
                return CompactionExtract(category: .social, content: content, importance: 4)
            }
            // Regular talk — lower priority, skip if too routine
            if content.count < 20 { return nil }
            return CompactionExtract(category: .social, content: content, importance: 2)

        case .build:
            return CompactionExtract(category: .strategy, content: content, importance: 3)

        case .observe:
            // Only keep significant observations
            let isSignificant = content.contains("trap") || content.contains("陷阱")
                || content.contains("house") || content.contains("ally")
                || content.count > 40
            if isSignificant {
                return CompactionExtract(category: .fact, content: content, importance: 2)
            }
            return nil

        case .move:
            // Movement is rarely worth persisting — only if exploring
            if content.contains("explore") || content.contains("discover") || content.contains("探索") {
                return CompactionExtract(category: .location, content: content, importance: 2)
            }
            return nil
        }
    }

    // MARK: - Continuity Bridge

    /// Build a bridge sentence that summarizes the agent's trajectory
    /// at the point of compaction — what they were doing, who they
    /// interacted with, and what their last significant action was.
    /// This prevents the "amnesia wall" that occurs after compaction.
    private func buildBridgeContext(from older: [MemoryEntry], into newer: [MemoryEntry]) -> String? {
        // Find the last significant entry (combat, talk, or build)
        let significant = older.reversed().first { $0.type == .combat || $0.type == .talk || $0.type == .build }

        // Find any agent names mentioned in older entries
        let allContent = older.map { $0.content }.joined(separator: " ")
        let mentionedAgents = extractAgentNames(from: allContent)

        var parts = [String]()

        if let sig = significant {
            parts.append("Last key event before this point: [\(sig.type.rawValue)] \(String(sig.content.prefix(100)))")
        }

        if !mentionedAgents.isEmpty {
            let names = mentionedAgents.prefix(4).joined(separator: ", ")
            parts.append("Agents encountered: \(names)")
        }

        // Type distribution — what was the agent focused on?
        var typeCounts: [MemoryEventType: Int] = [:]
        for e in older { typeCounts[e.type, default: 0] += 1 }
        if let dominant = typeCounts.max(by: { $0.value < $1.value }) {
            let focus: String
            switch dominant.key {
            case .combat: focus = "You were primarily engaged in combat."
            case .talk: focus = "You were primarily socializing and communicating."
            case .build: focus = "You were primarily building structures."
            case .move: focus = "You were primarily exploring and moving around."
            case .observe: focus = "You were primarily observing your surroundings."
            }
            parts.append(focus)
        }

        guard !parts.isEmpty else { return nil }
        return "⟨Memory Bridge⟩ " + parts.joined(separator: " ")
    }

    /// Simple heuristic to extract agent names from memory text.
    /// Looks for quoted names and known patterns like "Agent X" or "「name」".
    private func extractAgentNames(from text: String) -> [String] {
        var names = Set<String>()
        // Match patterns like "AgentName said", "AgentName attacked", quoted names
        let patterns = [
            try? NSRegularExpression(pattern: "\"([^\"]{1,20})\"\\s+(?:said|attacked|killed|built)", options: []),
            try? NSRegularExpression(pattern: "「([^」]{1,20})」", options: []),
            try? NSRegularExpression(pattern: "([A-Z][a-z]+(?:\\s[A-Z][a-z]+)?)\\s+(?:said|attacked|killed|built|is)", options: []),
        ].compactMap { $0 }
        let range = NSRange(text.startIndex..., in: text)
        for regex in patterns {
            for match in regex.matches(in: text, options: [], range: range) {
                if match.numberOfRanges > 1,
                   let nameRange = Range(match.range(at: 1), in: text) {
                    names.insert(String(text[nameRange]))
                }
            }
        }
        return Array(names)
    }

    /// Total number of recorded memories.
    var totalCount: Int { entries.count }
}
