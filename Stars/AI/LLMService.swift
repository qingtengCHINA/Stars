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

    /// Maximum concurrent API requests.
    /// URLSession and network stack handle the actual connection pooling;
    /// this limit prevents saturating API rate limits.
    /// With 100 agents and 5s average response time:
    ///   20 slots → each agent thinks every ~25s (fine for autonomous behavior)
    private let maxConcurrent = 20
    /// Extra slots reserved for agents replying to the player.
    private let priorityExtra = 3

    var canAcceptRequest: Bool { activeRequests < maxConcurrent }

    func reserveSlot() -> Bool {
        guard canAcceptRequest else { return false }
        activeRequests += 1
        return true
    }

    /// Priority slot for agents that need to reply to the player.
    /// Allows up to `maxConcurrent + priorityExtra` concurrent requests.
    func reservePrioritySlot() -> Bool {
        guard activeRequests < maxConcurrent + priorityExtra else { return false }
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
    /// On parse/format failure, retries ONCE with a simplified reminder prompt (if `allowRetry` is true).
    /// Pass `allowRetry: false` for autonomous thinks to avoid doubling slot occupation time.
    func sendPromptWithRaw(_ prompt: String, using config: ModelConfig, allowRetry: Bool = true) async throws -> (LLMResponse, String) {
        do {
            let (response, rawText) = try await sendPromptInternal(prompt, using: config)
            return (response, rawText)
        } catch let error as LLMError {
            switch error {
            case .parseFailed, .malformedResponse:
                guard allowRetry else { throw error }
                // Retry with a compact reminder prompt
                let retryPrompt = buildRetryPrompt(originalPrompt: prompt)
                let (response, rawText) = try await sendPromptInternal(retryPrompt, using: config)
                return (response, rawText)
            default:
                throw error
            }
        }
    }

    /// Build a shorter retry prompt that reminds the model of the JSON format.
    private func buildRetryPrompt(originalPrompt: String) -> String {
        // Take only the first ~2000 chars of the original prompt for context
        let contextSnippet = String(originalPrompt.prefix(2000))
        return """
        \(contextSnippet)
        ...

        ⚠️ YOUR LAST RESPONSE WAS INVALID. You MUST respond with ONLY a valid JSON object. No markdown, no explanation, no code fences.
        Example:
        {"thought":"I should explore","command":"/explore","action":"move","speech":null,"target":{"x":10,"y":5},"soulReflection":null,"customCommand":null}

        Respond with a single JSON object NOW:
        """
    }

    /// Send a context prompt to the configured LLM provider.
    func sendPrompt(_ prompt: String, using config: ModelConfig) async throws -> LLMResponse {
        let (response, _) = try await sendPromptInternal(prompt, using: config)
        return response
    }

    private func sendPromptInternal(_ prompt: String, using config: ModelConfig) async throws -> (LLMResponse, String) {

        guard let apiKey = ModelManager.shared.apiKey(for: config.id), !apiKey.isEmpty else {
            #if DEBUG
            print("[LLMService] ❌ Missing API key for config \(config.id) provider=\(config.provider.rawValue) isOfficial=\(config.provider.isOfficialProvider)")
            #endif
            throw LLMError.missingAPIKey
        }

        let endpointURL = config.resolvedBaseURL + config.provider.chatPath
        guard let url = URL(string: endpointURL) else {
            throw LLMError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        APIRequestHeaders.apply(to: &request, provider: config.provider, apiKey: apiKey)

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
            // the model just returned unexpected output. Mark as success.
            let isFreeTier = config.provider == .starsOfficial
            let formatMsg = isFreeTier
                ? "✅ 连接正常。免费模型偶尔返回格式有偏差，系统会自动重试，属于正常现象。"
                : "✅ 连接正常，但模型返回格式暂不符合 Stars 协议，系统将自动重试纠正。"
            ModelManager.shared.updateConnectionState(
                id: config.id,
                status: .success,
                message: formatMsg
            )
            let mapped = LLMError.malformedResponse(error.localizedDescription)
            throw mapped
        } catch let error as LLMError {
            switch error {
            case .parseFailed, .malformedResponse:
                // JSON parse/format errors — connection works, output format is wrong.
                // Still mark as success since the API endpoint IS reachable.
                let isFreeTier = config.provider == .starsOfficial
                let parseMsg = isFreeTier
                    ? "✅ 连接正常。免费模型输出偶有偏差，系统会自动重试。"
                    : "✅ 连接正常，但模型输出未通过 JSON 解析，系统将自动重试。"
                ModelManager.shared.updateConnectionState(
                    id: config.id,
                    status: .success,
                    message: parseMsg
                )
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
            let isTimeout = (error as NSError).code == NSURLErrorTimedOut
                || (error as NSError).code == NSURLErrorNetworkConnectionLost
            let displayMessage: String
            if isTimeout {
                displayMessage = "请求超时。可能原因：网络不稳定、模型响应慢、prompt 过长。"
            } else {
                displayMessage = error.localizedDescription
            }
            ModelManager.shared.updateConnectionState(
                id: config.id, status: .failure,
                message: displayMessage
            )
            throw LLMError.apiError(statusCode: (error as NSError).code, message: displayMessage)
        }
    }

    private func responseMaxTokens(for provider: APIProvider) -> Int {
        switch provider {
        case .anthropic:
            return 1500
        case .minimax:
            return 1200
        default:
            return 1200
        }
    }
}
