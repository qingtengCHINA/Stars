//
//  OfficialProviderConfig.swift
//  Stars
//
//  Configuration for developer-provided (official) model providers.
//  Reads API keys and model lists from the bundled stars-env file.
//
//  Tier → API Key mapping:
//    Free  → FREE_KEY   (openrouter/free)
//    Plus  → PLUS_KEY   (3 models)
//    Pro   → PRO_KEY    (7 models)
//    Max   → MAX_KEY    (2 models)
//
//  All official providers route through OpenRouter.
//

import Foundation

enum OfficialProviderConfig {

    struct TierConfig {
        let apiKey: String
        let models: [String]
    }

    // MARK: - Cached Tier Configs

    private static let configs: [SubscriptionTier: TierConfig] = {
        guard let env = loadEnv() else {
            print("[OfficialProviderConfig] Failed to load stars-env")
            return [:]
        }
        var result: [SubscriptionTier: TierConfig] = [:]

        if let key = env["FREE_KEY"], !key.isEmpty {
            let models = parseModelList(env["FREE_MODELS"])
            result[.free] = TierConfig(apiKey: key, models: models.isEmpty ? ["openrouter/free"] : models)
        }
        if let key = env["PLUS_KEY"], !key.isEmpty {
            let models = parseModelList(env["PLUS_MODELS"])
            result[.plus] = TierConfig(apiKey: key, models: models)
        }
        if let key = env["PRO_KEY"], !key.isEmpty {
            let models = parseModelList(env["PRO_MODELS"])
            result[.pro] = TierConfig(apiKey: key, models: models)
        }
        if let key = env["MAX_KEY"], !key.isEmpty {
            let models = parseModelList(env["MAX_MODELS"])
            result[.max] = TierConfig(apiKey: key, models: models)
        }

        return result
    }()

    // MARK: - Public API

    /// Get the API key for a subscription tier.
    static func apiKey(for tier: SubscriptionTier) -> String {
        configs[tier]?.apiKey ?? ""
    }

    /// Get the available models for a subscription tier.
    static func models(for tier: SubscriptionTier) -> [String] {
        configs[tier]?.models ?? []
    }

    /// Get the API key for an official provider.
    static func apiKey(for provider: APIProvider) -> String {
        switch provider {
        case .starsOfficial: return apiKey(for: .free)
        case .starsPlus:     return apiKey(for: .plus)
        case .starsPro:      return apiKey(for: .pro)
        case .starsMax:      return apiKey(for: .max)
        default:             return ""
        }
    }

    /// Get the available models for an official provider.
    static func models(for provider: APIProvider) -> [String] {
        switch provider {
        case .starsOfficial: return models(for: .free)
        case .starsPlus:     return models(for: .plus)
        case .starsPro:      return models(for: .pro)
        case .starsMax:      return models(for: .max)
        default:             return []
        }
    }

    /// Default model for a provider (first in list).
    static func defaultModel(for provider: APIProvider) -> String {
        models(for: provider).first ?? "openrouter/free"
    }

    // MARK: - .env Parser

    private static func loadEnv() -> [String: String]? {
        guard let url = Bundle.main.url(forResource: "stars-env", withExtension: nil)
                ?? Bundle.main.url(forResource: ".env", withExtension: nil)
        else {
            #if DEBUG
            print("[OfficialProviderConfig] ⚠️ stars-env file not found in bundle")
            #endif
            return nil
        }

        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var result = [String: String]()
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            result[key] = value
        }
        #if DEBUG
        print("[OfficialProviderConfig] Loaded \(result.count) keys from stars-env")
        #endif
        return result.isEmpty ? nil : result
    }

    private static func parseModelList(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
