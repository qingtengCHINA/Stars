//
//  AgentsFile.swift
//  Stars
//
//  The AGENTS file defines the shared world constitution — rules, laws,
//  and behavioural guidelines that every agent receives in their system prompt.
//  Players can edit this file through Settings to reshape the world's social contract.
//
//  Inspired by the OpenClaw project: AGENTS holds universal directives;
//  individual personality emerges in each agent's SOUL file.
//

import Foundation

@MainActor
final class AgentsFile {
    static let shared = AgentsFile()

    private let storageKey = "stars.agents.file"

    /// The raw text of the world constitution.
    private(set) var content: String

    private init() {
        if let saved = UserDefaults.standard.string(forKey: storageKey), !saved.isEmpty {
            content = saved
        } else {
            content = Self.defaultContent
        }
    }

    func update(_ newContent: String) {
        content = newContent
        UserDefaults.standard.set(newContent, forKey: storageKey)
        WorldEventLogStore.shared.append(
            category: .command,
            title: "AGENTS 文件更新",
            message: "世界规则已被主人修改。(\(newContent.count) 字符)"
        )
    }

    func reset() {
        update(Self.defaultContent)
    }

    /// Formatted section for injection into agent prompts.
    var promptSection: String {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return """
        === WORLD RULES (AGENTS FILE) ===
        \(content)
        === END WORLD RULES ===
        """
    }

    // MARK: - Default Content

    static let defaultContent = StarsConstitution.text
}
