//
//  APIRequestHeaders.swift
//  Stars
//
//  Shared utility for applying auth & provider-specific headers to URLRequests.
//  Used by both LLMService (chat) and ModelConnectionService (connection test).
//

import Foundation

enum APIRequestHeaders {

    /// Apply auth headers and provider-specific headers to a URLRequest.
    static func apply(to request: inout URLRequest, provider: APIProvider, apiKey: String) {
        switch provider.definition.authMode {
        case .bearer:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropicAPIKey:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .bearerAnthropicMessages:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }

        // OpenRouter recommended optional headers
        if provider == .openrouter {
            request.setValue("https://github.com/nicktmro/Stars", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Stars", forHTTPHeaderField: "X-Title")
        }
    }
}
