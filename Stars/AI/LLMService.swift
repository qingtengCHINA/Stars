//
//  LLMService.swift
//  Stars
//
//  Async network layer supporting OpenAI-compatible and Anthropic APIs.
//  All public API is MainActor-isolated — URLSession suspends without
//  blocking the main thread, so the game loop stays smooth.
//

import Foundation

@MainActor
final class LLMService {
    static let shared = LLMService()

    // MARK: - Concurrency Control

    private(set) var activeRequests = 0
    private let maxConcurrent = 3

    var canAcceptRequest: Bool { activeRequests < maxConcurrent }

    func reserveSlot() -> Bool {
        guard canAcceptRequest else { return false }
        activeRequests += 1
        return true
    }

    func releaseSlot() {
        activeRequests = max(0, activeRequests - 1)
    }

    // MARK: - Network

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 90
        session = URLSession(configuration: config)
    }

    /// Send a context prompt, returning both the parsed response and the raw text for token counting.
    func sendPromptWithRaw(_ prompt: String, using config: ModelConfig) async throws -> (LLMResponse, String) {
        let (response, rawText) = try await sendPromptInternal(prompt, using: config)
        return (response, rawText)
    }

    /// Send a context prompt to the configured LLM provider.
    func sendPrompt(_ prompt: String, using config: ModelConfig) async throws -> LLMResponse {
        let (response, _) = try await sendPromptInternal(prompt, using: config)
        return response
    }

    private func sendPromptInternal(_ prompt: String, using config: ModelConfig) async throws -> (LLMResponse, String) {

        guard let apiKey = ModelManager.shared.apiKey(for: config.id) else {
            throw LLMError.missingAPIKey
        }

        let endpointURL = config.resolvedBaseURL + config.provider.chatPath
        guard let url = URL(string: endpointURL) else {
            throw LLMError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch config.provider.definition.authMode {
        case .bearer:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropicAPIKey:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .bearerAnthropicMessages:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }

        request.httpBody = try ProviderPayloadCodec.makeBody(
            prompt: prompt,
            model: config.modelName,
            provider: config.provider,
            temperature: 0.8,
            maxTokens: responseMaxTokens(for: config.provider)
        )

        do {
            // Async — suspends MainActor, does NOT block game loop
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }

            guard (200...299).contains(http.statusCode) else {
                let msg = ProviderPayloadCodec.responsePreview(from: data)
                throw LLMError.apiError(statusCode: http.statusCode, message: msg)
            }

            let content = try ProviderPayloadCodec.extractText(from: data, provider: config.provider)
            let parsed = try ActionResolver.parse(content)
            ModelManager.shared.updateConnectionState(
                id: config.id,
                status: .success,
                message: "聊天接口已验证，可正常解析响应。"
            )
            return (parsed, content)
        } catch let error as ProviderPayloadError {
            // Response parsing errors mean the connection IS working —
            // the model just returned unexpected output.
            // Do NOT overwrite a successful connection test status.
            let mapped = LLMError.malformedResponse(error.localizedDescription)
            throw mapped
        } catch let error as LLMError {
            switch error {
            case .parseFailed, .malformedResponse:
                // JSON parse/format errors — connection works, output format is wrong.
                // Do NOT overwrite connection test status.
                break
            case .apiError, .invalidResponse, .missingAPIKey, .rateLimited:
                // Real connection/auth problems — update status.
                ModelManager.shared.updateConnectionState(
                    id: config.id, status: .failure,
                    message: error.localizedDescription
                )
            }
            throw error
        } catch {
            // Network errors (timeout, DNS, etc.) — real connection problems.
            ModelManager.shared.updateConnectionState(
                id: config.id, status: .failure,
                message: error.localizedDescription
            )
            throw error
        }
    }

    private func responseMaxTokens(for provider: APIProvider) -> Int {
        switch provider {
        case .minimax:
            return 1024
        case .anthropic:
            return 1024
        default:
            return 800
        }
    }
}
