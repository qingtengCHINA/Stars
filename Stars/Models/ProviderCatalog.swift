//
//  ProviderCatalog.swift
//  Stars
//

import Foundation

enum ProviderProtocolFamily {
    case openAIChatCompletions
    case anthropicMessages
}

enum ProviderAuthMode {
    case bearer
    case anthropicAPIKey
    case bearerAnthropicMessages
}

enum ProviderModelCatalogMode {
    case remoteOpenAIList(path: String)
    case staticCatalog
}

struct ProviderDefinition {
    let provider: APIProvider
    let displayName: String
    let selectionTitle: String
    let selectionSubtitle: String
    let defaultBaseURL: String
    let apiKeyPlaceholder: String
    let defaultModel: String
    let defaultAppendV1: Bool
    let chatPath: String
    let protocolFamily: ProviderProtocolFamily
    let authMode: ProviderAuthMode
    let modelCatalogMode: ProviderModelCatalogMode
    let catalogModels: [String]
    let docsURL: String
    let protocolLabel: String
    let authLabel: String
    let contextWindowTokens: Int

    var modelSourceLabel: String {
        switch modelCatalogMode {
        case .remoteOpenAIList:
            return "远程模型列表 + 手动输入"
        case .staticCatalog:
            return catalogModels.isEmpty ? "仅手动输入模型名" : "内置参考模型目录 + 手动输入"
        }
    }
}

enum ProviderCatalog {

    /// Official providers shown at the top of the picker, filtered by subscription tier.
    static let officialProviders: [APIProvider] = [
        .starsMax,
        .starsPro,
        .starsPlus,
        .starsOfficial,
    ]

    /// Third-party providers always visible in the picker.
    static let orderedProviders: [APIProvider] = [
        .openai,
        .anthropic,
        .minimax,
        .gemini,
        .deepseek,
        .moonshot,
        .modelStudio,
        .openrouter,
        .groq,
        .mistral,
        .perplexity,
        .ark,
        .bigmodel,
        .hunyuan,
        .xiaomiMimo,
        .nvidiaNIM,
        .inceptionLabs,
        .qianfan,
        .xai,
        .zai,
        .customOpenAICompatible,
    ]

    static let definitions: [APIProvider: ProviderDefinition] = [
        // ── Official Providers ──
        .starsOfficial: ProviderDefinition(
            provider: .starsOfficial,
            displayName: "QingTeng",
            selectionTitle: "QingTeng（群星官方）",
            selectionSubtitle: "免费系统模型，由开发者提供",
            defaultBaseURL: "https://openrouter.ai/api",
            apiKeyPlaceholder: "",
            defaultModel: "openrouter/free",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: OfficialProviderConfig.models(for: .starsOfficial),
            docsURL: "",
            protocolLabel: "Stars Official",
            authLabel: "System",
            contextWindowTokens: 128_000
        ),
        .starsPlus: ProviderDefinition(
            provider: .starsPlus,
            displayName: "Stars Plus",
            selectionTitle: "Stars Plus",
            selectionSubtitle: "Plus 订阅专属模型",
            defaultBaseURL: "https://openrouter.ai/api",
            apiKeyPlaceholder: "",
            defaultModel: OfficialProviderConfig.defaultModel(for: .starsPlus),
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: OfficialProviderConfig.models(for: .starsPlus),
            docsURL: "",
            protocolLabel: "Stars Plus",
            authLabel: "System",
            contextWindowTokens: 128_000
        ),
        .starsPro: ProviderDefinition(
            provider: .starsPro,
            displayName: "Stars Pro",
            selectionTitle: "Stars Pro",
            selectionSubtitle: "Pro 订阅专属模型",
            defaultBaseURL: "https://openrouter.ai/api",
            apiKeyPlaceholder: "",
            defaultModel: OfficialProviderConfig.defaultModel(for: .starsPro),
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: OfficialProviderConfig.models(for: .starsPro),
            docsURL: "",
            protocolLabel: "Stars Pro",
            authLabel: "System",
            contextWindowTokens: 128_000
        ),
        .starsMax: ProviderDefinition(
            provider: .starsMax,
            displayName: "Stars Max",
            selectionTitle: "Stars Max",
            selectionSubtitle: "Max 订阅专属模型",
            defaultBaseURL: "https://openrouter.ai/api",
            apiKeyPlaceholder: "",
            defaultModel: OfficialProviderConfig.defaultModel(for: .starsMax),
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: OfficialProviderConfig.models(for: .starsMax),
            docsURL: "",
            protocolLabel: "Stars Max",
            authLabel: "System",
            contextWindowTokens: 200_000
        ),

        // ── Third-party Providers ──
        .openai: ProviderDefinition(
            provider: .openai,
            displayName: "OpenAI",
            selectionTitle: "OpenAI",
            selectionSubtitle: "官方 Chat 兼容接口",
            defaultBaseURL: "https://api.openai.com",
            apiKeyPlaceholder: "sk-...",
            defaultModel: "gpt-4o",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .remoteOpenAIList(path: "/models"),
            catalogModels: ["gpt-4.1-mini", "gpt-4.1", "gpt-5"],
            docsURL: "https://developers.openai.com/api/reference/overview/",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .anthropic: ProviderDefinition(
            provider: .anthropic,
            displayName: "Anthropic",
            selectionTitle: "Anthropic",
            selectionSubtitle: "Claude Messages 接口",
            defaultBaseURL: "https://api.anthropic.com/v1",
            apiKeyPlaceholder: "sk-ant-...",
            defaultModel: "claude-sonnet-4-20250514",
            defaultAppendV1: false,
            chatPath: "/messages",
            protocolFamily: .anthropicMessages,
            authMode: .anthropicAPIKey,
            modelCatalogMode: .staticCatalog,
            catalogModels: [
                "claude-sonnet-4-20250514",
                "claude-opus-4-20250514",
            ]
            ,
            docsURL: "https://docs.anthropic.com/en/api/overview",
            protocolLabel: "Anthropic Messages",
            authLabel: "x-api-key + anthropic-version",
            contextWindowTokens: 200_000
        ),
        .minimax: ProviderDefinition(
            provider: .minimax,
            displayName: "MiniMax",
            selectionTitle: "MiniMax",
            selectionSubtitle: "Anthropic Messages 兼容，实际请求落到 /anthropic/v1/messages",
            defaultBaseURL: "https://api.minimaxi.com/anthropic/v1",
            apiKeyPlaceholder: "sk-api-...",
            defaultModel: "MiniMax-M2.7",
            defaultAppendV1: false,
            chatPath: "/messages",
            protocolFamily: .anthropicMessages,
            authMode: .bearerAnthropicMessages,
            modelCatalogMode: .staticCatalog,
            catalogModels: [
                "MiniMax-M2.7",
                "MiniMax-M2.7-highspeed",
                "MiniMax-M2.5",
                "MiniMax-M2.5-highspeed",
                "MiniMax-M2.1",
                "MiniMax-M2.1-highspeed",
                "MiniMax-M2",
            ],
            docsURL: "https://platform.minimaxi.com/docs/api-reference/text-anthropic-api",
            protocolLabel: "Anthropic Messages 兼容",
            authLabel: "Authorization: Bearer + anthropic-version",
            contextWindowTokens: 128_000
        ),
        .gemini: ProviderDefinition(
            provider: .gemini,
            displayName: "Gemini",
            selectionTitle: "Google Gemini",
            selectionSubtitle: "Gemini OpenAI 兼容层",
            defaultBaseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
            apiKeyPlaceholder: "AIza...",
            defaultModel: "gemini-2.5-flash",
            defaultAppendV1: false,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: [
                "gemini-2.5-flash",
                "gemini-2.5-pro",
                "gemini-3.1-flash-lite-preview",
                "gemini-3.1-pro-preview",
            ],
            docsURL: "https://ai.google.dev/gemini-api/docs",
            protocolLabel: "OpenAI 兼容层",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .deepseek: ProviderDefinition(
            provider: .deepseek,
            displayName: "DeepSeek",
            selectionTitle: "DeepSeek",
            selectionSubtitle: "官方 Chat Completions 接口",
            defaultBaseURL: "https://api.deepseek.com",
            apiKeyPlaceholder: "sk-...",
            defaultModel: "deepseek-chat",
            defaultAppendV1: false,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: [
                "deepseek-chat",
                "deepseek-reasoner",
                "DeepSeek-V3.2",
                "DeepSeek-R1",
            ],
            docsURL: "https://api-docs.deepseek.com/",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 64_000
        ),
        .moonshot: ProviderDefinition(
            provider: .moonshot,
            displayName: "Moonshot",
            selectionTitle: "Moonshot",
            selectionSubtitle: "Kimi OpenAI 兼容接口",
            defaultBaseURL: "https://api.moonshot.ai",
            apiKeyPlaceholder: "sk-...",
            defaultModel: "moonshot-v1-8k",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"],
            docsURL: "https://platform.moonshot.ai/docs/overview",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .modelStudio: ProviderDefinition(
            provider: .modelStudio,
            displayName: "Qwen / DashScope",
            selectionTitle: "Qwen / DashScope",
            selectionSubtitle: "阿里云百炼 OpenAI 兼容接口",
            defaultBaseURL: "https://dashscope.aliyuncs.com/compatible-mode",
            apiKeyPlaceholder: "sk-...",
            defaultModel: "qwen-plus",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: [
                "qwen-plus",
                "qwen-turbo",
                "qwen-max",
                "qwen-plus-latest",
            ],
            docsURL: "https://help.aliyun.com/zh/model-studio/qwen-api-reference/",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .openrouter: ProviderDefinition(
            provider: .openrouter,
            displayName: "OpenRouter",
            selectionTitle: "OpenRouter",
            selectionSubtitle: "OpenAI 兼容聚合入口",
            defaultBaseURL: "https://openrouter.ai/api",
            apiKeyPlaceholder: "sk-or-...",
            defaultModel: "openai/gpt-4.1-mini",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .remoteOpenAIList(path: "/models"),
            catalogModels: ["openai/gpt-4.1-mini", "anthropic/claude-sonnet-4", "google/gemini-2.5-flash"],
            docsURL: "https://openrouter.ai/docs/api/reference/overview",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .groq: ProviderDefinition(
            provider: .groq,
            displayName: "Groq",
            selectionTitle: "Groq",
            selectionSubtitle: "OpenAI 兼容高速推理入口",
            defaultBaseURL: "https://api.groq.com/openai",
            apiKeyPlaceholder: "gsk_...",
            defaultModel: "llama-3.3-70b-versatile",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: [
                "llama-3.3-70b-versatile",
                "llama-3.1-8b-instant",
                "llama-4-scout-17b-16e-instruct",
                "llama-4-maverick-17b-128e-instruct",
            ],
            docsURL: "https://console.groq.com/docs/api-reference",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .mistral: ProviderDefinition(
            provider: .mistral,
            displayName: "Mistral",
            selectionTitle: "Mistral",
            selectionSubtitle: "Mistral OpenAI 兼容接口",
            defaultBaseURL: "https://api.mistral.ai",
            apiKeyPlaceholder: "sk-...",
            defaultModel: "mistral-large-latest",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["mistral-large-latest", "mistral-medium-latest", "codestral-latest"],
            docsURL: "https://docs.mistral.ai/api/",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .perplexity: ProviderDefinition(
            provider: .perplexity,
            displayName: "Perplexity",
            selectionTitle: "Perplexity",
            selectionSubtitle: "Sonar Chat Completions",
            defaultBaseURL: "https://api.perplexity.ai",
            apiKeyPlaceholder: "pplx-...",
            defaultModel: "sonar",
            defaultAppendV1: false,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["sonar", "sonar-pro", "sonar-reasoning", "sonar-reasoning-pro"],
            docsURL: "https://docs.perplexity.ai/",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .ark: ProviderDefinition(
            provider: .ark,
            displayName: "Ark",
            selectionTitle: "火山方舟 Ark",
            selectionSubtitle: "OpenAI 兼容接口",
            defaultBaseURL: "https://ark.cn-beijing.volces.com/api/v3",
            apiKeyPlaceholder: "ark-...",
            defaultModel: "doubao-seed-1-6-250615",
            defaultAppendV1: false,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["doubao-seed-1-6-250615", "doubao-1-5-pro-32k", "doubao-1-5-lite-32k"],
            docsURL: "https://www.volcengine.com/docs/82379",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .bigmodel: ProviderDefinition(
            provider: .bigmodel,
            displayName: "BigModel / Zhipu",
            selectionTitle: "BigModel / 智谱",
            selectionSubtitle: "GLM OpenAI 兼容接口",
            defaultBaseURL: "https://open.bigmodel.cn/api/paas/v4",
            apiKeyPlaceholder: "sk-...",
            defaultModel: "glm-5",
            defaultAppendV1: false,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["glm-5", "glm-5-turbo", "glm-4.7", "glm-4.7-flash"],
            docsURL: "https://docs.bigmodel.cn/",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .hunyuan: ProviderDefinition(
            provider: .hunyuan,
            displayName: "Hunyuan",
            selectionTitle: "腾讯混元",
            selectionSubtitle: "OpenAI 兼容接口",
            defaultBaseURL: "https://api.hunyuan.cloud.tencent.com",
            apiKeyPlaceholder: "hk-...",
            defaultModel: "hunyuan-turbos-latest",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["hunyuan-turbos-latest", "hunyuan-turbos", "hunyuan-lite", "hunyuan-functioncall"],
            docsURL: "https://cloud.tencent.com/document/product/1729",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .xiaomiMimo: ProviderDefinition(
            provider: .xiaomiMimo,
            displayName: "Xiaomi MiMo",
            selectionTitle: "Xiaomi MiMo",
            selectionSubtitle: "OpenAI 兼容接口，需按文档填写 base URL",
            defaultBaseURL: "",
            apiKeyPlaceholder: "mimo-...",
            defaultModel: "mimo-7b-chat",
            defaultAppendV1: false,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["mimo-7b-chat"],
            docsURL: "https://platform.xiaomimimo.com/#/docs/welcome",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .nvidiaNIM: ProviderDefinition(
            provider: .nvidiaNIM,
            displayName: "NVIDIA NIM",
            selectionTitle: "NVIDIA NIM",
            selectionSubtitle: "OpenAI 兼容接口，需填写你的 NIM endpoint",
            defaultBaseURL: "",
            apiKeyPlaceholder: "nvapi-...",
            defaultModel: "meta/llama-3.1-70b-instruct",
            defaultAppendV1: false,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["meta/llama-3.1-70b-instruct"],
            docsURL: "https://docs.api.nvidia.com/nim/reference/introduction",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 64_000
        ),
        .inceptionLabs: ProviderDefinition(
            provider: .inceptionLabs,
            displayName: "Inception Labs",
            selectionTitle: "Inception Labs",
            selectionSubtitle: "OpenAI 兼容接口",
            defaultBaseURL: "https://api.inceptionlabs.ai",
            apiKeyPlaceholder: "sk-...",
            defaultModel: "mercury-2",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["mercury-2"],
            docsURL: "https://docs.inceptionlabs.ai/",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .qianfan: ProviderDefinition(
            provider: .qianfan,
            displayName: "Qianfan",
            selectionTitle: "Qianfan",
            selectionSubtitle: "百度千帆 OpenAI 兼容接口",
            defaultBaseURL: "https://qianfan.baidubce.com/v2",
            apiKeyPlaceholder: "bce-v3/...",
            defaultModel: "DeepSeek-R1",
            defaultAppendV1: false,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["DeepSeek-R1", "ERNIE-4.5-Turbo-128K", "ERNIE-4.5-8K"],
            docsURL: "https://cloud.baidu.com/doc/qianfan/index.html",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .xai: ProviderDefinition(
            provider: .xai,
            displayName: "xAI",
            selectionTitle: "xAI",
            selectionSubtitle: "Grok OpenAI 兼容接口",
            defaultBaseURL: "https://api.x.ai",
            apiKeyPlaceholder: "xai-...",
            defaultModel: "grok-4",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["grok-4", "grok-4-0709", "grok-4-1-fast-reasoning", "grok-3"],
            docsURL: "https://docs.x.ai/",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .zai: ProviderDefinition(
            provider: .zai,
            displayName: "Z.ai",
            selectionTitle: "Z.ai / GLM",
            selectionSubtitle: "GLM OpenAI 兼容接口",
            defaultBaseURL: "https://api.z.ai/api/paas/v4",
            apiKeyPlaceholder: "sk-...",
            defaultModel: "glm-5",
            defaultAppendV1: false,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: ["glm-5", "glm-5-turbo", "glm-4.7", "glm-4.7-flash"],
            docsURL: "https://docs.bigmodel.cn/",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
        .customOpenAICompatible: ProviderDefinition(
            provider: .customOpenAICompatible,
            displayName: "Custom OpenAI-Compatible",
            selectionTitle: "自定义 OpenAI 兼容",
            selectionSubtitle: "手动填写 base URL / model / key",
            defaultBaseURL: "",
            apiKeyPlaceholder: "sk-...",
            defaultModel: "custom-model",
            defaultAppendV1: true,
            chatPath: "/chat/completions",
            protocolFamily: .openAIChatCompletions,
            authMode: .bearer,
            modelCatalogMode: .staticCatalog,
            catalogModels: [],
            docsURL: "https://developers.openai.com/api/reference/overview/",
            protocolLabel: "OpenAI Chat Completions",
            authLabel: "Authorization: Bearer",
            contextWindowTokens: 128_000
        ),
    ]

    static func definition(for provider: APIProvider) -> ProviderDefinition {
        guard let definition = definitions[provider] else {
            fatalError("Missing provider definition for \(provider.rawValue)")
        }
        return definition
    }
}
