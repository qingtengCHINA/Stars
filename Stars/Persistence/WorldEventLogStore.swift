//
//  WorldEventLogStore.swift
//  Stars
//

import Foundation

enum WorldEventCategory: String, Codable, Sendable {
    case persistence
    case model
    case chat
    case command
    case build
    case combat
    case context
    case lifecycle
}

struct WorldEventRecord: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let category: WorldEventCategory
    let entityID: String?
    let title: String
    let message: String
    let metadata: [String: String]
}

final class WorldEventLogStore {
    static let shared = WorldEventLogStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "stars.event-log.store", qos: .utility)
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {}

    func append(
        category: WorldEventCategory,
        entityID: String? = nil,
        title: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        let record = WorldEventRecord(
            id: UUID(),
            timestamp: Date(),
            category: category,
            entityID: entityID,
            title: title,
            message: message,
            metadata: metadata
        )

        queue.async { [weak self] in
            try? self?.appendRecord(record)
        }
    }

    func recentEvents(limit: Int, entityID: String? = nil) -> [WorldEventRecord] {
        queue.sync {
            guard let url = try? logURL(),
                  let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else {
                return []
            }

            let records = text
                .split(separator: "\n")
                .compactMap { line -> WorldEventRecord? in
                    guard let data = String(line).data(using: .utf8) else { return nil }
                    return try? decoder.decode(WorldEventRecord.self, from: data)
                }
                .filter { record in
                    guard let entityID else { return true }
                    return record.entityID == entityID
                }

            return Array(records.suffix(limit))
        }
    }

    func clear() {
        queue.async { [weak self] in
            guard let self, let url = try? self.logURL(), self.fileManager.fileExists(atPath: url.path) else { return }
            try? self.fileManager.removeItem(at: url)
        }
    }

    private func appendRecord(_ record: WorldEventRecord) throws {
        let url = try logURL()
        let directoryURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        let encoded = try encoder.encode(record)
        guard var line = String(data: encoded, encoding: .utf8)?.data(using: .utf8) else { return }
        line.append(0x0A)

        if !fileManager.fileExists(atPath: url.path) {
            try line.write(to: url, options: .atomic)
        } else {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        }

        try trimIfNeeded(at: url)
    }

    private func trimIfNeeded(at url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count > 4000 else { return }

        let trimmed = lines.suffix(2500).joined(separator: "\n") + "\n"
        guard let trimmedData = trimmed.data(using: .utf8) else { return }
        try trimmedData.write(to: url, options: .atomic)
    }

    private func logURL() throws -> URL {
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return baseDirectory
            .appendingPathComponent("Stars", isDirectory: true)
            .appendingPathComponent("event-log.jsonl", isDirectory: false)
    }
}
