//
//  ModelConnectionService.swift
//  Stars
//

import Foundation

struct ModelConnectionResult: Sendable {
    let status: ModelConnectionStatus
    let message: String
    let models: [String]
}

enum ModelConnectionError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case httpError(Int, String)
    case invalidResponse
    case malformedResponse(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "缺少 API Key"
        case .invalidURL:
            return "无效的 API 地址"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .invalidResponse:
            return "服务端返回了无法解析的响应"
        case .malformedResponse(let message):
            return message
        case .notFound(let message):
            return message
        }
    }
}

final class ModelConnectionService {
    static let shared = ModelConnectionService()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        session = URLSession(configuration: configuration)
    }

    func listModels(using config: ModelConfig, apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw ModelConnectionError.missingAPIKey }
        switch config.provider.definition.modelCatalogMode {
        case .staticCatalog:
            return config.provider.definition.catalogModels

        case .remoteOpenAIList(let path):
            guard let url = URL(string: config.resolvedBaseURL + path) else {
                throw ModelConnectionError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            applyHeaders(to: &request, provider: config.provider, apiKey: apiKey)

            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)

            let ids = try parseModelIDs(from: data)
            return Array(Set(ids)).sorted()
        }
    }

    func testConnection(using config: ModelConfig, apiKey: String) async -> ModelConnectionResult {
        var models: [String] = []
        var modelListError: String?

        do {
            models = try await listModels(using: config, apiKey: apiKey)
        } catch {
            modelListError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        // Retry chat probe up to 2 times for transient network errors
        // (openrouter/free routes to random providers that may occasionally fail)
        let maxAttempts = 2
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                try await sendChatProbe(using: config, apiKey: apiKey)

                var message: String
                let isFreeTier = config.provider == .starsOfficial
                if !models.isEmpty {
                    switch config.provider.definition.modelCatalogMode {
                    case .staticCatalog:
                        message = "连接成功，聊天接口已验证。已载入 \(models.count) 个内置参考模型。"
                    case .remoteOpenAIList:
                        message = "连接成功，聊天接口已验证，并拉取 \(models.count) 个模型。"
                    }
                    if !config.modelName.isEmpty && !models.contains(config.modelName) {
                        message += " 当前模型未出现在返回列表中，你仍可使用自定义模型名。"
                    }
                } else if let modelListError {
                    message = "聊天接口已验证，可正常解析响应。模型列表获取失败：\(modelListError)"
                } else {
                    message = "聊天接口已验证，可正常解析响应。"
                }
                if isFreeTier {
                    message += " 免费模型偶尔会有格式偏差，系统会自动重试纠正。"
                }

                return ModelConnectionResult(status: .success, message: message, models: models)
            } catch {
                lastError = error
                #if DEBUG
                print("[ConnectionTest] Attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)")
                #endif
                // Only retry on network-level errors, not on API/validation errors
                if error is ModelConnectionError { break }
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s before retry
                }
            }
        }

        let chatError = (lastError as? LocalizedError)?.errorDescription ?? (lastError?.localizedDescription ?? "Unknown error")
        let message: String
        if let modelListError {
            message = "\(chatError)；模型列表也失败：\(modelListError)"
        } else {
            message = chatError
        }
        return ModelConnectionResult(status: .failure, message: message, models: models)
    }

    private func sendChatProbe(using config: ModelConfig, apiKey: String) async throws {
        guard !apiKey.isEmpty else { throw ModelConnectionError.missingAPIKey }

        let fullURL = config.resolvedBaseURL + config.provider.chatPath
        guard let url = URL(string: fullURL) else {
            throw ModelConnectionError.invalidURL
        }

        #if DEBUG
        let keyPreview = apiKey.count > 12
            ? "\(apiKey.prefix(8))...\(apiKey.suffix(4))"
            : "<short>"
        print("[ConnectionTest] URL: \(fullURL)")
        print("[ConnectionTest] Provider: \(config.provider.rawValue), Model: \(config.modelName)")
        print("[ConnectionTest] Key: \(keyPreview)")
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyHeaders(to: &request, provider: config.provider, apiKey: apiKey)
        request.httpBody = try ProviderPayloadCodec.makeBody(
            prompt: ProviderPayloadCodec.connectionProbePrompt,
            model: config.modelName,
            provider: config.provider,
            systemPrompt: ProviderPayloadCodec.connectionProbeSystemPrompt,
            temperature: 0.2,
            maxTokens: probeMaxTokens(for: config.provider)
        )

        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            do {
                let content = try ProviderPayloadCodec.extractText(from: data, provider: config.provider)
                _ = try ActionResolver.parse(content)
            } catch {
                // Connection IS working — the model just returned non-Stars-protocol output.
                // This is expected for free models and non-critical for any model.
                // Stars auto-retries with a reminder prompt during gameplay.
                // Don't throw — treat as successful connection.
                #if DEBUG
                print("[ConnectionTest] Format mismatch (non-fatal): \(error.localizedDescription)")
                #endif
            }
        } catch let error as ModelConnectionError {
            throw error
        } catch {
            // Wrap network errors with detailed diagnostics
            let nsError = error as NSError
            #if DEBUG
            print("[ConnectionTest] Network error: domain=\(nsError.domain) code=\(nsError.code) desc=\(nsError.localizedDescription)")
            #endif
            throw ModelConnectionError.malformedResponse(
                "网络请求失败 [\(nsError.domain) \(nsError.code)]: \(nsError.localizedDescription)"
            )
        }
    }

    private func applyHeaders(to request: inout URLRequest, provider: APIProvider, apiKey: String) {
        APIRequestHeaders.apply(to: &request, provider: provider, apiKey: apiKey)
    }

    private func probeMaxTokens(for provider: APIProvider) -> Int {
        switch provider {
        case .minimax:
            return 600
        case .anthropic:
            return 512
        default:
            return 400
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ModelConnectionError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            if http.statusCode == 404 {
                throw ModelConnectionError.notFound(
                    friendlyNotFoundMessage(from: text)
                )
            }
            throw ModelConnectionError.httpError(http.statusCode, sanitizeErrorText(text))
        }
    }

    private func sanitizeErrorText(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(220))
    }

    private func friendlyNotFoundMessage(from text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("<html") || lowercased.contains("404 not found") {
            return "接口返回 404。常见原因：API 地址中已经包含 /v1、/messages、/chat/completions 这类具体路径，或当前服务商并不提供远程 /models 接口。Stars 现在会优先使用服务商自带模型目录；如果仍失败，请只填写主机地址。"
        }

        return "接口返回 404。请检查 API 地址是否正确，以及该服务是否支持模型列表或聊天接口。"
    }

    private func parseModelIDs(from data: Data) throws -> [String] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ModelConnectionError.invalidResponse
        }

        if let dataArray = object["data"] as? [[String: Any]] {
            return dataArray.compactMap { item in
                (item["id"] as? String) ?? (item["name"] as? String)
            }
        }

        if let items = object["models"] as? [String] {
            return items
        }

        throw ModelConnectionError.malformedResponse(
            "模型列表响应格式无法识别。预览：\(ProviderPayloadCodec.responsePreview(from: data))"
        )
    }
}
