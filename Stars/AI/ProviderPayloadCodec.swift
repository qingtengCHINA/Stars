//
//  ProviderPayloadCodec.swift
//  Stars
//

import Foundation

enum ProviderPayloadError: LocalizedError {
    case malformedResponse(String)

    var errorDescription: String? {
        switch self {
        case .malformedResponse(let message):
            return message
        }
    }
}

enum ProviderPayloadCodec {
    static let defaultSystemPrompt = """
    You are an AI-driven agent in a 2D pixel sandbox game called "Stars". Always respond with a single valid JSON object and nothing else.
    """

    static let connectionProbeSystemPrompt = """
    You are validating a game-agent chat connection. Return exactly one JSON object and nothing else.
    """

    static let connectionProbePrompt = """
    Return exactly this JSON shape and nothing else:
    {"thought":"probe","command":"/talk","action":"talk","speech":"OK","target":null}
    """

    static func makeBody(
        prompt: String,
        model: String,
        provider: APIProvider,
        systemPrompt: String = defaultSystemPrompt,
        temperature: Double,
        maxTokens: Int
    ) throws -> Data {
        switch provider.definition.protocolFamily {
        case .openAIChatCompletions:
            return try JSONSerialization.data(withJSONObject: [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": prompt],
                ],
                "temperature": temperature,
                "max_tokens": maxTokens,
            ])

        case .anthropicMessages:
            return try JSONSerialization.data(withJSONObject: [
                "model": model,
                "system": systemPrompt,
                "messages": [
                    ["role": "user", "content": prompt],
                ],
                "temperature": temperature,
                "max_tokens": maxTokens,
            ])
        }
    }

    static func extractText(from data: Data, provider: APIProvider) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderPayloadError.malformedResponse(
                "Response is not a JSON object. Preview: \(responsePreview(from: data))"
            )
        }

        switch provider.definition.protocolFamily {
        case .openAIChatCompletions:
            return try extractOpenAIText(from: json, originalData: data)
        case .anthropicMessages:
            return try extractAnthropicText(from: json, originalData: data)
        }
    }

    static func responsePreview(from data: Data, limit: Int = 260) -> String {
        let raw = String(data: data, encoding: .utf8) ?? "<non-UTF8 response>"
        let collapsed = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(limit))
    }

    private static func extractOpenAIText(from json: [String: Any], originalData: Data) throws -> String {
        if let error = extractErrorMessage(from: json) {
            throw ProviderPayloadError.malformedResponse(error)
        }

        // Check for truncation (finish_reason: "length")
        let isTruncated: Bool = {
            guard let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let reason = first["finish_reason"] as? String else { return false }
            return reason == "length"
        }()

        if let choices = json["choices"] as? [[String: Any]] {
            for choice in choices {
                if let message = choice["message"] as? [String: Any],
                   let content = extractTextValue(from: message["content"]),
                   !content.isEmpty {
                    // If truncated, try to repair incomplete JSON
                    return isTruncated ? repairTruncatedJSON(content) : content
                }

                if let delta = choice["delta"] as? [String: Any],
                   let content = extractTextValue(from: delta["content"]),
                   !content.isEmpty {
                    return isTruncated ? repairTruncatedJSON(content) : content
                }

                if let text = extractTextValue(from: choice["text"]),
                   !text.isEmpty {
                    return isTruncated ? repairTruncatedJSON(text) : text
                }
            }
        }

        if let outputText = extractTextValue(from: json["output_text"]),
           !outputText.isEmpty {
            return isTruncated ? repairTruncatedJSON(outputText) : outputText
        }

        if isTruncated {
            throw ProviderPayloadError.malformedResponse(
                "模型输出被截断（finish_reason: length）。模型在生成完整 JSON 前耗尽了 max_tokens。Preview: \(responsePreview(from: originalData))"
            )
        }

        throw ProviderPayloadError.malformedResponse(
            "Missing assistant text in OpenAI-compatible response. Preview: \(responsePreview(from: originalData))"
        )
    }

    private static func extractAnthropicText(from json: [String: Any], originalData: Data) throws -> String {
        if let error = extractErrorMessage(from: json) {
            throw ProviderPayloadError.malformedResponse(error)
        }

        // Check for truncation (stop_reason: "max_tokens")
        let isTruncated: Bool = {
            guard let reason = json["stop_reason"] as? String else { return false }
            return reason == "max_tokens"
        }()

        if let blocks = json["content"] as? [Any] {
            let textBlocks = blocks.compactMap { extractAnthropicContentText(from: $0) }
            let joined = textBlocks
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                return isTruncated ? repairTruncatedJSON(joined) : joined
            }

            // If only thinking blocks exist, try to extract JSON from thinking text
            if containsAnthropicThinkingBlock(in: blocks) {
                if let jsonFromThinking = extractJSONFromThinkingBlocks(blocks) {
                    return jsonFromThinking
                }
                throw ProviderPayloadError.malformedResponse(
                    "Anthropic 兼容接口仅返回 thinking 块，没有最终文本。通常是 max_tokens 不足，模型在思考阶段就耗尽了 token。Preview: \(responsePreview(from: originalData))"
                )
            }
        }

        if let content = extractTextValue(from: json["content"]),
           !content.isEmpty {
            return isTruncated ? repairTruncatedJSON(content) : content
        }

        if isTruncated {
            throw ProviderPayloadError.malformedResponse(
                "Anthropic 兼容接口输出被截断（stop_reason: max_tokens）。模型在生成完整响应前耗尽了 token。Preview: \(responsePreview(from: originalData))"
            )
        }

        throw ProviderPayloadError.malformedResponse(
            "Missing assistant text in Anthropic-compatible response. Preview: \(responsePreview(from: originalData))"
        )
    }

    private static func extractErrorMessage(from json: [String: Any]) -> String? {
        if let error = json["error"] as? [String: Any] {
            let type = error["type"] as? String
            let message = (error["message"] as? String) ?? responsePreview(fromJSONObject: error)
            if let type, !type.isEmpty {
                return "\(type): \(message)"
            }
            return message
        }

        if let baseResp = json["base_resp"] as? [String: Any],
           let statusCode = baseResp["status_code"] as? Int,
           statusCode != 0 {
            let statusMessage = (baseResp["status_msg"] as? String) ?? "Unknown provider error"
            return "Provider status \(statusCode): \(statusMessage)"
        }

        return nil
    }

    private static func extractTextValue(from value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed

        case let array as [Any]:
            let parts = array.compactMap { extractTextValue(from: $0) }
            let joined = parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined

        case let dict as [String: Any]:
            let directCandidates: [String?] = [
                dict["text"] as? String,
                dict["output_text"] as? String,
                dict["value"] as? String,
            ]

            for candidate in directCandidates {
                if let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            if let nestedText = extractTextValue(from: dict["content"]) {
                return nestedText
            }

            if let nestedText = extractTextValue(from: dict["text"]) {
                return nestedText
            }

            if let nestedText = extractTextValue(from: dict["value"]) {
                return nestedText
            }

            return nil

        default:
            return nil
        }
    }

    private static func extractAnthropicContentText(from value: Any) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed

        case let dict as [String: Any]:
            if let type = dict["type"] as? String,
               type.localizedCaseInsensitiveContains("thinking") {
                return nil
            }

            if dict["thinking"] != nil {
                return nil
            }

            if let text = dict["text"] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }

            if let outputText = dict["output_text"] as? String {
                let trimmed = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }

            if let value = dict["value"] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }

            if let nested = dict["content"] {
                return extractAnthropicContentText(from: nested)
            }

            return nil

        case let array as [Any]:
            let parts = array.compactMap { extractAnthropicContentText(from: $0) }
            let joined = parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined

        default:
            return nil
        }
    }

    private static func containsAnthropicThinkingBlock(in blocks: [Any]) -> Bool {
        blocks.contains { block in
            guard let dict = block as? [String: Any] else { return false }
            if dict["thinking"] != nil {
                return true
            }
            if let type = dict["type"] as? String {
                return type.localizedCaseInsensitiveContains("thinking")
            }
            return false
        }
    }

    private static func responsePreview(fromJSONObject object: Any, limit: Int = 260) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else {
            return "<unserializable JSON>"
        }
        return responsePreview(from: data, limit: limit)
    }

    // MARK: - Truncated JSON Repair

    /// Attempt to close unclosed strings and braces in truncated JSON.
    /// When a model runs out of max_tokens mid-output, the JSON is often
    /// nearly complete — just missing closing braces/quotes.
    static func repairTruncatedJSON(_ text: String) -> String {
        // First, try to find a complete JSON object within the text
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}"),
           start < end {
            let candidate = String(text[start...end])
            if let data = candidate.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return candidate
            }
        }

        // If no complete JSON, try to repair by closing unclosed structures
        guard let start = text.firstIndex(of: "{") else { return text }
        var s = String(text[start...])

        var inString = false
        var escaped = false
        var openBraces = 0
        var openBrackets = 0
        var lastNonWhitespace: Character = " "

        for char in s {
            if escaped { escaped = false; continue }
            if char == "\\" && inString { escaped = true; continue }
            if char == "\"" { inString = !inString; continue }
            if inString { continue }
            if char == "{" { openBraces += 1 }
            if char == "}" { openBraces -= 1 }
            if char == "[" { openBrackets += 1 }
            if char == "]" { openBrackets -= 1 }
            if !char.isWhitespace { lastNonWhitespace = char }
        }

        // Close unclosed string
        if inString {
            s += "\""
            lastNonWhitespace = "\""
        }

        // If we ended mid-value (after a colon or comma), add a null placeholder
        if lastNonWhitespace == ":" || lastNonWhitespace == "," {
            s += "null"
        }

        // Close unclosed brackets and braces
        for _ in 0..<max(0, openBrackets) { s += "]" }
        for _ in 0..<max(0, openBraces) { s += "}" }

        return s
    }

    /// Try to extract JSON from Anthropic thinking blocks.
    /// Some providers (MiniMax) put all content in thinking and exhaust tokens
    /// before producing a text block. If the thinking contains a JSON object
    /// that matches our expected schema, extract it.
    private static func extractJSONFromThinkingBlocks(_ blocks: [Any]) -> String? {
        for block in blocks {
            guard let dict = block as? [String: Any] else { continue }
            let text: String?
            if let thinking = dict["thinking"] as? String {
                text = thinking
            } else if let type = dict["type"] as? String,
                      type.localizedCaseInsensitiveContains("thinking"),
                      let t = dict["text"] as? String {
                text = t
            } else {
                continue
            }

            guard let thinkingText = text else { continue }

            // Search for a JSON object containing "thought" and "action" keys
            if let start = thinkingText.range(of: "{"),
               let end = thinkingText.range(of: "}", options: .backwards) {
                let candidate = String(thinkingText[start.lowerBound...end.upperBound])
                if candidate.contains("\"thought\"") && candidate.contains("\"action\"") {
                    if let data = candidate.data(using: .utf8),
                       (try? JSONSerialization.jsonObject(with: data)) != nil {
                        return candidate
                    }
                    // Try repairing if it's almost valid
                    let repaired = repairTruncatedJSON(candidate)
                    if let data = repaired.data(using: .utf8),
                       (try? JSONSerialization.jsonObject(with: data)) != nil {
                        return repaired
                    }
                }
            }
        }
        return nil
    }
}
