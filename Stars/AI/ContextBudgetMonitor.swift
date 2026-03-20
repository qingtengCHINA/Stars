//
//  ContextBudgetMonitor.swift
//  Stars
//

import Foundation

struct ContextUsageSnapshot: Sendable {
    let usedTokens: Int          // estimated prompt tokens
    let limitTokens: Int
    let didCompact: Bool
    let compactedMemoryEntries: Int
    let compactedChatMessages: Int
    let responseTokens: Int      // estimated response tokens (0 if not yet received)

    init(usedTokens: Int, limitTokens: Int, didCompact: Bool = false,
         compactedMemoryEntries: Int = 0, compactedChatMessages: Int = 0,
         responseTokens: Int = 0) {
        self.usedTokens = usedTokens
        self.limitTokens = limitTokens
        self.didCompact = didCompact
        self.compactedMemoryEntries = compactedMemoryEntries
        self.compactedChatMessages = compactedChatMessages
        self.responseTokens = responseTokens
    }

    var usageRatio: Double {
        guard limitTokens > 0 else { return 0 }
        return Double(usedTokens) / Double(limitTokens)
    }

    var percentageText: String {
        "\(Int((usageRatio * 100).rounded()))%"
    }
}

enum ContextBudgetMonitor {
    /// Estimate token count with CJK awareness.
    /// - ASCII / Latin characters: ~4 chars per token (GPT/Claude average)
    /// - CJK ideographs & fullwidth punctuation: ~1.5 tokens per character
    /// This intentionally over-estimates to leave headroom.
    static func estimateTokens(for text: String) -> Int {
        var asciiChars = 0
        var cjkChars = 0

        for scalar in text.unicodeScalars {
            let v = scalar.value
            if v <= 0x7F {
                // Basic ASCII
                asciiChars += 1
            } else if (0x2E80...0x9FFF).contains(v)    // CJK Radicals, Kangxi, CJK Unified
                   || (0xF900...0xFAFF).contains(v)     // CJK Compatibility Ideographs
                   || (0xFE30...0xFE4F).contains(v)     // CJK Compatibility Forms
                   || (0xFF00...0xFFEF).contains(v)     // Fullwidth Forms (，。！etc)
                   || (0x20000...0x2FA1F).contains(v)   // CJK Extension B-F
                   || (0x3000...0x303F).contains(v)     // CJK Symbols & Punctuation
                   || (0x3040...0x30FF).contains(v)     // Hiragana + Katakana
                   || (0xAC00...0xD7AF).contains(v)     // Hangul Syllables
            {
                cjkChars += 1
            } else {
                // Other multi-byte (emoji, diacritics, etc.) — treat conservatively
                cjkChars += 1
            }
        }

        let asciiTokens = Double(asciiChars) / 4.0
        let cjkTokens = Double(cjkChars) * 1.5
        return max(1, Int((asciiTokens + cjkTokens).rounded(.up)))
    }
}
