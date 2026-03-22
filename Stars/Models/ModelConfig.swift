//
//  ModelConfig.swift
//  Stars
//

import Foundation

// MARK: - API Provider

enum APIProvider: String, Codable, CaseIterable {
    // Official (developer-provided) providers
    case starsOfficial          // QingTeng (群星官方) — Free tier
    case starsPlus              // Stars Plus models
    case starsPro               // Stars Pro models
    case starsMax               // Stars Max models

    // Third-party providers
    case openai
    case anthropic
    case openrouter
    case minimax
    case gemini
    case deepseek
    case moonshot
    case modelStudio
    case groq
    case mistral
    case perplexity
    case ark
    case bigmodel
    case hunyuan
    case xiaomiMimo
    case nvidiaNIM
    case inceptionLabs
    case qianfan
    case xai
    case zai
    case customOpenAICompatible

    var displayName: String {
        definition.displayName
    }

    var defaultBaseURL: String {
        definition.defaultBaseURL
    }

    var apiKeyPlaceholder: String {
        definition.apiKeyPlaceholder
    }

    var defaultModel: String {
        definition.defaultModel
    }

    /// Endpoint path appended after the resolved base URL.
    var chatPath: String {
        definition.chatPath
    }

    var defaultAppendV1: Bool {
        definition.defaultAppendV1
    }

    var definition: ProviderDefinition {
        ProviderCatalog.definition(for: self)
    }

    // MARK: - Official Provider Helpers

    /// True for developer-provided official providers (QingTeng / Plus / Pro / Max).
    var isOfficialProvider: Bool {
        switch self {
        case .starsOfficial, .starsPlus, .starsPro, .starsMax: return true
        default: return false
        }
    }

    /// Minimum subscription tier required to use this provider.
    var requiredSubscriptionTier: SubscriptionTier {
        switch self {
        case .starsOfficial: return .free
        case .starsPlus:     return .plus
        case .starsPro:      return .pro
        case .starsMax:      return .max
        default:             return .free
        }
    }

    /// Maximum number of agents allowed for this official provider.
    var officialAgentLimit: Int {
        switch self {
        case .starsOfficial: return 5
        case .starsPlus:     return 10
        case .starsPro:      return 5
        case .starsMax:      return 3
        default:             return 0
        }
    }
}

enum ModelConnectionStatus: String, Codable, Sendable {
    case unknown
    case success
    case failure

    var displayText: String {
        switch self {
        case .unknown: return "未测试"
        case .success: return "连接正常"
        case .failure: return "连接失败"
        }
    }
}

// MARK: - Model Config

struct ModelConfig: Codable, Identifiable {
    let id: UUID
    var alias: String
    var provider: APIProvider
    var baseURL: String        // custom override; empty = provider default
    var modelName: String
    var appendV1: Bool
    var connectionStatus: ModelConnectionStatus
    var connectionMessage: String?

    init(id: UUID = UUID(), alias: String, provider: APIProvider = .openai,
         baseURL: String = "", modelName: String = "",
         appendV1: Bool? = nil,
         connectionStatus: ModelConnectionStatus = .unknown,
         connectionMessage: String? = nil) {
        self.id = id
        self.alias = alias
        self.provider = provider
        self.baseURL = baseURL
        self.modelName = modelName.isEmpty ? provider.defaultModel : modelName
        self.appendV1 = appendV1 ?? provider.defaultAppendV1
        self.connectionStatus = connectionStatus
        self.connectionMessage = connectionMessage
    }

    // Backward compatibility — old configs lack provider / appendV1
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self, forKey: .id)
        alias     = try c.decode(String.self, forKey: .alias)
        provider  = try c.decodeIfPresent(APIProvider.self, forKey: .provider) ?? .openai
        modelName = try c.decode(String.self, forKey: .modelName)
        appendV1  = try c.decodeIfPresent(Bool.self, forKey: .appendV1) ?? provider.defaultAppendV1
        connectionStatus = try c.decodeIfPresent(ModelConnectionStatus.self, forKey: .connectionStatus) ?? .unknown
        connectionMessage = try c.decodeIfPresent(String.self, forKey: .connectionMessage)

        var rawURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        // Old format stored full path like "https://api.openai.com/v1".
        // Strip trailing /v1 since appendV1 now handles it.
        let isNewFormat = c.contains(.appendV1)
        if !isNewFormat && rawURL.hasSuffix("/v1") {
            rawURL = String(rawURL.dropLast(3))
        }

        // Migration: Anthropic protocol no longer uses the appendV1 toggle.
        // If an old config had appendV1=true with a custom base URL, bake /v1
        // into the base URL so the resolved endpoint stays the same.
        if provider.definition.protocolFamily == .anthropicMessages {
            if appendV1 && !rawURL.isEmpty && !rawURL.hasSuffix("/v1") {
                rawURL += "/v1"
            }
            appendV1 = false
        }

        baseURL = rawURL
    }

    /// Full base URL with /v1 appended when enabled.
    var resolvedBaseURL: String {
        normalizeBaseURL(baseURL.isEmpty ? provider.defaultBaseURL : baseURL)
    }

    private func normalizeBaseURL(_ rawValue: String) -> String {
        var url = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        while url.hasSuffix("/") {
            url.removeLast()
        }

        let removableSuffixes = [
            provider.chatPath,
            "/models",
        ]

        for suffix in removableSuffixes where url.hasSuffix(suffix) {
            url.removeLast(suffix.count)
            while url.hasSuffix("/") {
                url.removeLast()
            }
        }

        while url.hasSuffix("/v1/v1") {
            url.removeLast(3)
        }

        // MiniMax: if user enters just the host, expand to the full Anthropic-compat path.
        if provider == .minimax {
            if let parsed = URL(string: url),
               parsed.host == "api.minimaxi.com",
               (parsed.path.isEmpty || parsed.path == "/") {
                return "https://api.minimaxi.com/anthropic/v1"
            }
            if url.hasSuffix("/anthropic"),
               !url.hasSuffix("/anthropic/v1") {
                return url + "/v1"
            }
        }

        // appendV1 only applies to OpenAI-compatible protocols.
        // Anthropic-compatible protocols bake /v1 into the base URL itself.
        if appendV1 && provider.definition.protocolFamily == .openAIChatCompletions {
            if !url.hasSuffix("/v1") {
                url += "/v1"
            }
        }

        return url
    }
}
