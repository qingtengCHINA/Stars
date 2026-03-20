//
//  IncrementalArchiveStore.swift
//  Stars
//

import Foundation

enum WorldDeltaKind: String, Codable, Sendable {
    case checkpoint
    case agent
    case structure
    case customCommands
}

struct WorldDeltaRecord: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let reason: String
    let kind: WorldDeltaKind
    let agent: AgentSnapshot?
    let structure: StructureSnapshot?
    let customCommands: [CommandAliasProposal]?
}

final class IncrementalArchiveStore {
    static let shared = IncrementalArchiveStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "stars.incremental-archive.store", qos: .utility)
    private var lastRecordTime: [String: Date] = [:]  // entityID → last write time
    private let throttleInterval: TimeInterval = 2.0  // min seconds between writes per entity
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

    func recordAgent(_ agent: Agent, reason: String) {
        let now = Date()
        if let last = lastRecordTime[agent.entityID],
           now.timeIntervalSince(last) < throttleInterval {
            return
        }
        lastRecordTime[agent.entityID] = now
        append(
            WorldDeltaRecord(
                id: UUID(),
                timestamp: now,
                reason: reason,
                kind: .agent,
                agent: AgentSnapshot(agent: agent),
                structure: nil,
                customCommands: nil
            )
        )
    }

    func recordStructure(_ structure: Structure, reason: String) {
        let now = Date()
        if let last = lastRecordTime[structure.entityID],
           now.timeIntervalSince(last) < throttleInterval {
            return
        }
        lastRecordTime[structure.entityID] = now
        append(
            WorldDeltaRecord(
                id: UUID(),
                timestamp: now,
                reason: reason,
                kind: .structure,
                agent: nil,
                structure: StructureSnapshot(structure: structure),
                customCommands: nil
            )
        )
    }

    func recordCustomCommands(_ commands: [CommandAliasProposal], reason: String) {
        append(
            WorldDeltaRecord(
                id: UUID(),
                timestamp: Date(),
                reason: reason,
                kind: .customCommands,
                agent: nil,
                structure: nil,
                customCommands: commands
            )
        )
    }

    func reset(after checkpoint: GameStateSnapshot) {
        lastRecordTime.removeAll()
        let marker = WorldDeltaRecord(
            id: UUID(),
            timestamp: checkpoint.savedAt,
            reason: "full-checkpoint",
            kind: .checkpoint,
            agent: nil,
            structure: nil,
            customCommands: nil
        )

        queue.async { [weak self] in
            do {
                guard let self else { return }
                let url = try self.archiveURL()
                let directoryURL = url.deletingLastPathComponent()
                try self.fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                let data = try self.lineData(for: marker)
                try data.write(to: url, options: .atomic)
            } catch {
                print("[Persistence] Failed to reset incremental archive: \(error.localizedDescription)")
            }
        }
    }

    func applyPendingDeltas(to snapshot: GameStateSnapshot) -> GameStateSnapshot {
        queue.sync {
            guard let url = try? archiveURL(),
                  let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else {
                return snapshot
            }

            let deltas = text
                .split(separator: "\n")
                .compactMap { line -> WorldDeltaRecord? in
                    guard let data = String(line).data(using: .utf8) else { return nil }
                    return try? decoder.decode(WorldDeltaRecord.self, from: data)
                }
                .filter { $0.timestamp > snapshot.savedAt }
                .sorted { $0.timestamp < $1.timestamp }

            guard !deltas.isEmpty else { return snapshot }

            var agentsByID = Dictionary(uniqueKeysWithValues: snapshot.agents.map { ($0.entityID, $0) })
            var structuresByID = Dictionary(uniqueKeysWithValues: snapshot.structures.map { ($0.entityID, $0) })
            var customCommands = snapshot.customCommands
            var latestTimestamp = snapshot.savedAt

            for delta in deltas {
                latestTimestamp = max(latestTimestamp, delta.timestamp)
                switch delta.kind {
                case .checkpoint:
                    continue
                case .agent:
                    if let agent = delta.agent {
                        agentsByID[agent.entityID] = agent
                    }
                case .structure:
                    if let structure = delta.structure {
                        if structure.hp > 0 {
                            structuresByID[structure.entityID] = structure
                        } else {
                            structuresByID.removeValue(forKey: structure.entityID)
                        }
                    }
                case .customCommands:
                    if let commands = delta.customCommands {
                        customCommands = commands
                    }
                }
            }

            return GameStateSnapshot(
                schemaVersion: GameStateSnapshot.currentSchemaVersion,
                savedAt: latestTimestamp,
                agents: agentsByID.values.sorted { $0.displayName < $1.displayName },
                structures: structuresByID.values.sorted { lhs, rhs in
                    if lhs.tileY == rhs.tileY {
                        return lhs.tileX < rhs.tileX
                    }
                    return lhs.tileY < rhs.tileY
                },
                camera: snapshot.camera,
                customCommands: customCommands
            )
        }
    }

    private func append(_ record: WorldDeltaRecord) {
        queue.async { [weak self] in
            do {
                guard let self else { return }
                let url = try self.archiveURL()
                let directoryURL = url.deletingLastPathComponent()
                try self.fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                let line = try self.lineData(for: record)

                if !self.fileManager.fileExists(atPath: url.path) {
                    try line.write(to: url, options: .atomic)
                } else {
                    let handle = try FileHandle(forWritingTo: url)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: line)
                }
            } catch {
                print("[Persistence] Failed to append delta record: \(error.localizedDescription)")
            }
        }
    }

    private func lineData(for record: WorldDeltaRecord) throws -> Data {
        let encoded = try encoder.encode(record)
        guard var line = String(data: encoded, encoding: .utf8)?.data(using: .utf8) else {
            return Data()
        }
        line.append(0x0A)
        return line
    }

    private func archiveURL() throws -> URL {
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return baseDirectory
            .appendingPathComponent("Stars", isDirectory: true)
            .appendingPathComponent("incremental-archive.jsonl", isDirectory: false)
    }
}
