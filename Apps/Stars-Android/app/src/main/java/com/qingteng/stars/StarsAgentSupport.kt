package com.qingteng.stars

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.absoluteValue
import kotlin.math.roundToInt

enum class SubscriptionTier(
    val rank: Int,
    val displayName: String,
) {
    Free(0, "Free"),
    Plus(1, "Plus"),
    Pro(2, "Pro"),
    Max(3, "Max");
}

data class QtcTransaction(
    val timestamp: Long,
    val amount: Int,
    val reason: String,
    val balance: Int,
)

data class QtcState(
    val balance: Int = 0,
    val totalSpent: Int = 0,
    val transactions: List<QtcTransaction> = emptyList(),
) {
    val maxAgents: Int
        get() = FREE_AGENT_LIMIT + totalSpent

    fun addCredits(amount: Int, reason: String): QtcState {
        if (amount <= 0) return this
        val nextBalance = balance + amount
        return copy(
            balance = nextBalance,
            transactions = (transactions + QtcTransaction(System.currentTimeMillis(), amount, reason, nextBalance)).takeLast(100),
        )
    }

    fun spendForAgentSlot(): QtcState? {
        if (balance <= 0) return null
        val nextBalance = balance - 1
        return copy(
            balance = nextBalance,
            totalSpent = totalSpent + 1,
            transactions = (transactions + QtcTransaction(System.currentTimeMillis(), -1, "解锁额外 Agent 槽位", nextBalance)).takeLast(100),
        )
    }

    companion object {
        const val FREE_AGENT_LIMIT = 20
    }
}

sealed interface AddAgentGate {
    object Allowed : AddAgentGate
    data class RequireSpendQtc(val balance: Int) : AddAgentGate
    data class RequireQtcPurchase(val balance: Int) : AddAgentGate
}

enum class ProviderAuthMode {
    Bearer,
    AnthropicApiKey,
    BearerAnthropicMessages,
}

sealed interface ProviderModelCatalogMode {
    data class RemoteOpenAIList(val path: String) : ProviderModelCatalogMode
    object StaticCatalog : ProviderModelCatalogMode
}

data class ProviderDefinition(
    val provider: APIProvider,
    val displayName: String,
    val selectionTitle: String,
    val selectionSubtitle: String,
    val defaultBaseURL: String,
    val apiKeyPlaceholder: String,
    val defaultModel: String,
    val defaultAppendV1: Boolean,
    val chatPath: String,
    val protocolFamily: ProviderProtocolFamily,
    val authMode: ProviderAuthMode,
    val modelCatalogMode: ProviderModelCatalogMode,
    val catalogModels: List<String>,
    val docsURL: String,
    val protocolLabel: String,
    val authLabel: String,
    val contextWindowTokens: Int,
) {
    val modelSourceLabel: String
        get() = when (modelCatalogMode) {
            is ProviderModelCatalogMode.RemoteOpenAIList -> "远程模型列表 + 手动输入"
            ProviderModelCatalogMode.StaticCatalog -> if (catalogModels.isEmpty()) "仅手动输入模型名" else "内置参考模型目录 + 手动输入"
        }
}

object ProviderCatalog {
    val officialProviders: List<APIProvider> = listOf(
        APIProvider.StarsMax,
        APIProvider.StarsPro,
        APIProvider.StarsPlus,
        APIProvider.StarsOfficial,
    )

    val orderedProviders: List<APIProvider> = listOf(
        APIProvider.OpenAI,
        APIProvider.Anthropic,
        APIProvider.MiniMax,
        APIProvider.Gemini,
        APIProvider.DeepSeek,
        APIProvider.Moonshot,
        APIProvider.ModelStudio,
        APIProvider.OpenRouter,
        APIProvider.Groq,
        APIProvider.Mistral,
        APIProvider.Perplexity,
        APIProvider.Ark,
        APIProvider.BigModel,
        APIProvider.Hunyuan,
        APIProvider.XiaomiMimo,
        APIProvider.NvidiaNIM,
        APIProvider.InceptionLabs,
        APIProvider.Qianfan,
        APIProvider.XAI,
        APIProvider.ZAI,
        APIProvider.CustomOpenAICompatible,
    )

    private val providerDefinitions: Map<APIProvider, ProviderDefinition> = mapOf(
        APIProvider.StarsOfficial to ProviderDefinition(
            provider = APIProvider.StarsOfficial,
            displayName = "QingTeng",
            selectionTitle = "QingTeng（群星官方）",
            selectionSubtitle = "免费系统模型，由开发者提供",
            defaultBaseURL = "https://openrouter.ai/api",
            apiKeyPlaceholder = "",
            defaultModel = "openrouter/free",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("openrouter/free"),
            docsURL = "",
            protocolLabel = "Stars Official",
            authLabel = "System",
            contextWindowTokens = 128_000,
        ),
        APIProvider.StarsPlus to ProviderDefinition(
            provider = APIProvider.StarsPlus,
            displayName = "Stars Plus",
            selectionTitle = "Stars Plus",
            selectionSubtitle = "Plus 订阅专属模型",
            defaultBaseURL = "https://openrouter.ai/api",
            apiKeyPlaceholder = "",
            defaultModel = "openai/gpt-oss-120b",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("openai/gpt-oss-120b", "deepseek/deepseek-v3.2", "x-ai/grok-4.1-fast"),
            docsURL = "",
            protocolLabel = "Stars Plus",
            authLabel = "System",
            contextWindowTokens = 256_000,
        ),
        APIProvider.StarsPro to ProviderDefinition(
            provider = APIProvider.StarsPro,
            displayName = "Stars Pro",
            selectionTitle = "Stars Pro",
            selectionSubtitle = "Pro 订阅专属模型",
            defaultBaseURL = "https://openrouter.ai/api",
            apiKeyPlaceholder = "",
            defaultModel = "openai/gpt-5.4-mini",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf(
                "xiaomi/mimo-v2-omni",
                "google/gemini-2.5-flash",
                "moonshotai/kimi-k2.5",
                "z-ai/glm-5",
                "openai/gpt-5.4-mini",
                "minimax/minimax-m2.7",
                "google/gemini-3-flash-preview",
            ),
            docsURL = "",
            protocolLabel = "Stars Pro",
            authLabel = "System",
            contextWindowTokens = 256_000,
        ),
        APIProvider.StarsMax to ProviderDefinition(
            provider = APIProvider.StarsMax,
            displayName = "Stars Max",
            selectionTitle = "Stars Max",
            selectionSubtitle = "Max 订阅专属模型",
            defaultBaseURL = "https://openrouter.ai/api",
            apiKeyPlaceholder = "",
            defaultModel = "anthropic/claude-sonnet-4.6",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("anthropic/claude-sonnet-4.6", "openai/gpt-5.3-codex"),
            docsURL = "",
            protocolLabel = "Stars Max",
            authLabel = "System",
            contextWindowTokens = 256_000,
        ),
        APIProvider.OpenAI to ProviderDefinition(
            provider = APIProvider.OpenAI,
            displayName = "OpenAI",
            selectionTitle = "OpenAI",
            selectionSubtitle = "官方 Chat 兼容接口",
            defaultBaseURL = "https://api.openai.com",
            apiKeyPlaceholder = "sk-...",
            defaultModel = "gpt-4.1-mini",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.RemoteOpenAIList("/models"),
            catalogModels = emptyList(),
            docsURL = "https://platform.openai.com/docs/api-reference/chat",
            protocolLabel = "OpenAI",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.Anthropic to ProviderDefinition(
            provider = APIProvider.Anthropic,
            displayName = "Anthropic",
            selectionTitle = "Anthropic",
            selectionSubtitle = "Claude Messages 接口",
            defaultBaseURL = "https://api.anthropic.com",
            apiKeyPlaceholder = "sk-ant-...",
            defaultModel = "claude-3-5-sonnet-latest",
            defaultAppendV1 = false,
            chatPath = "/v1/messages",
            protocolFamily = ProviderProtocolFamily.Anthropic,
            authMode = ProviderAuthMode.AnthropicApiKey,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf(
                "claude-3-5-sonnet-latest",
                "claude-3-5-haiku-latest",
                "claude-3-opus-latest",
            ),
            docsURL = "https://docs.anthropic.com/en/api/messages",
            protocolLabel = "Anthropic",
            authLabel = "x-api-key",
            contextWindowTokens = 200_000,
        ),
        APIProvider.OpenRouter to ProviderDefinition(
            provider = APIProvider.OpenRouter,
            displayName = "OpenRouter",
            selectionTitle = "OpenRouter",
            selectionSubtitle = "OpenAI 兼容聚合入口",
            defaultBaseURL = "https://openrouter.ai/api",
            apiKeyPlaceholder = "sk-or-v1-...",
            defaultModel = "openai/gpt-4.1-mini",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.RemoteOpenAIList("/models"),
            catalogModels = emptyList(),
            docsURL = "https://openrouter.ai/docs/quickstart",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 256_000,
        ),
        APIProvider.MiniMax to ProviderDefinition(
            provider = APIProvider.MiniMax,
            displayName = "MiniMax",
            selectionTitle = "MiniMax",
            selectionSubtitle = "Anthropic Messages 兼容，实际请求落到 /anthropic/v1/messages",
            defaultBaseURL = "https://api.minimaxi.com/anthropic",
            apiKeyPlaceholder = "minimax-...",
            defaultModel = "MiniMax-Text-01",
            defaultAppendV1 = false,
            chatPath = "/v1/messages",
            protocolFamily = ProviderProtocolFamily.Anthropic,
            authMode = ProviderAuthMode.BearerAnthropicMessages,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("MiniMax-Text-01", "MiniMax-M2", "MiniMax-M2.5"),
            docsURL = "https://www.minimaxi.com/platform/document",
            protocolLabel = "Anthropic Compat",
            authLabel = "Bearer + anthropic-version",
            contextWindowTokens = 128_000,
        ),
        APIProvider.Gemini to ProviderDefinition(
            provider = APIProvider.Gemini,
            displayName = "Gemini",
            selectionTitle = "Google Gemini",
            selectionSubtitle = "Gemini OpenAI 兼容层",
            defaultBaseURL = "https://generativelanguage.googleapis.com/v1beta/openai",
            apiKeyPlaceholder = "AIza...",
            defaultModel = "gemini-2.0-flash",
            defaultAppendV1 = false,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-1.5-pro"),
            docsURL = "https://ai.google.dev/gemini-api/docs/openai",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 1_000_000,
        ),
        APIProvider.DeepSeek to ProviderDefinition(
            provider = APIProvider.DeepSeek,
            displayName = "DeepSeek",
            selectionTitle = "DeepSeek",
            selectionSubtitle = "官方 Chat Completions 接口",
            defaultBaseURL = "https://api.deepseek.com",
            apiKeyPlaceholder = "sk-...",
            defaultModel = "deepseek-chat",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("deepseek-chat", "deepseek-reasoner"),
            docsURL = "https://api-docs.deepseek.com/",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.Moonshot to ProviderDefinition(
            provider = APIProvider.Moonshot,
            displayName = "Moonshot",
            selectionTitle = "Moonshot",
            selectionSubtitle = "Kimi OpenAI 兼容接口",
            defaultBaseURL = "https://api.moonshot.cn",
            apiKeyPlaceholder = "sk-...",
            defaultModel = "moonshot-v1-8k",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"),
            docsURL = "https://platform.moonshot.cn/docs/api-reference",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.ModelStudio to ProviderDefinition(
            provider = APIProvider.ModelStudio,
            displayName = "Model Studio",
            selectionTitle = "Qwen / DashScope",
            selectionSubtitle = "阿里云百炼 OpenAI 兼容接口",
            defaultBaseURL = "https://dashscope.aliyuncs.com/compatible-mode",
            apiKeyPlaceholder = "sk-...",
            defaultModel = "qwen-plus",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("qwen-turbo", "qwen-plus", "qwen-max"),
            docsURL = "https://help.aliyun.com/zh/dashscope/",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.Groq to ProviderDefinition(
            provider = APIProvider.Groq,
            displayName = "Groq",
            selectionTitle = "Groq",
            selectionSubtitle = "OpenAI 兼容高速推理入口",
            defaultBaseURL = "https://api.groq.com/openai",
            apiKeyPlaceholder = "gsk_...",
            defaultModel = "llama-3.1-70b-versatile",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("llama-3.1-8b-instant", "llama-3.1-70b-versatile", "mixtral-8x7b-32768"),
            docsURL = "https://console.groq.com/docs/openai",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.Mistral to ProviderDefinition(
            provider = APIProvider.Mistral,
            displayName = "Mistral",
            selectionTitle = "Mistral",
            selectionSubtitle = "Mistral OpenAI 兼容接口",
            defaultBaseURL = "https://api.mistral.ai",
            apiKeyPlaceholder = "mistral-...",
            defaultModel = "mistral-small-latest",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("mistral-small-latest", "mistral-medium-latest", "codestral-latest"),
            docsURL = "https://docs.mistral.ai/",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.Perplexity to ProviderDefinition(
            provider = APIProvider.Perplexity,
            displayName = "Perplexity",
            selectionTitle = "Perplexity",
            selectionSubtitle = "Sonar Chat Completions",
            defaultBaseURL = "https://api.perplexity.ai",
            apiKeyPlaceholder = "pplx-...",
            defaultModel = "llama-3.1-sonar-small-128k-online",
            defaultAppendV1 = false,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("llama-3.1-sonar-small-128k-online", "llama-3.1-sonar-large-128k-online", "sonar-pro"),
            docsURL = "https://docs.perplexity.ai/",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.Ark to ProviderDefinition(
            provider = APIProvider.Ark,
            displayName = "Ark",
            selectionTitle = "火山方舟 Ark",
            selectionSubtitle = "OpenAI 兼容接口",
            defaultBaseURL = "",
            apiKeyPlaceholder = "ark-...",
            defaultModel = "",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = emptyList(),
            docsURL = "https://www.volcengine.com/docs/82379",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.BigModel to ProviderDefinition(
            provider = APIProvider.BigModel,
            displayName = "BigModel / 智谱",
            selectionTitle = "BigModel / 智谱",
            selectionSubtitle = "GLM OpenAI 兼容接口",
            defaultBaseURL = "https://open.bigmodel.cn/api/paas",
            apiKeyPlaceholder = "glm-...",
            defaultModel = "glm-4-flash",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("glm-4-flash", "glm-4-plus", "glm-4-air"),
            docsURL = "https://open.bigmodel.cn/dev/api#glm-4",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.Hunyuan to ProviderDefinition(
            provider = APIProvider.Hunyuan,
            displayName = "Hunyuan",
            selectionTitle = "腾讯混元",
            selectionSubtitle = "OpenAI 兼容接口",
            defaultBaseURL = "",
            apiKeyPlaceholder = "sk-...",
            defaultModel = "",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = emptyList(),
            docsURL = "https://cloud.tencent.com/document/product/1729",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.XiaomiMimo to ProviderDefinition(
            provider = APIProvider.XiaomiMimo,
            displayName = "Xiaomi MiMo",
            selectionTitle = "Xiaomi MiMo",
            selectionSubtitle = "OpenAI 兼容接口，需按文档填写 base URL",
            defaultBaseURL = "",
            apiKeyPlaceholder = "mimo-...",
            defaultModel = "",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = emptyList(),
            docsURL = "https://platform.xiaomi.com/docs/mimo/",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.NvidiaNIM to ProviderDefinition(
            provider = APIProvider.NvidiaNIM,
            displayName = "NVIDIA NIM",
            selectionTitle = "NVIDIA NIM",
            selectionSubtitle = "OpenAI 兼容接口，需填写你的 NIM endpoint",
            defaultBaseURL = "",
            apiKeyPlaceholder = "nvapi-...",
            defaultModel = "",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = emptyList(),
            docsURL = "https://build.nvidia.com/",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.InceptionLabs to ProviderDefinition(
            provider = APIProvider.InceptionLabs,
            displayName = "Inception Labs",
            selectionTitle = "Inception Labs",
            selectionSubtitle = "OpenAI 兼容接口",
            defaultBaseURL = "",
            apiKeyPlaceholder = "sk-...",
            defaultModel = "",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = emptyList(),
            docsURL = "https://docs.inceptionlabs.ai/",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.Qianfan to ProviderDefinition(
            provider = APIProvider.Qianfan,
            displayName = "Qianfan",
            selectionTitle = "Qianfan",
            selectionSubtitle = "百度千帆 OpenAI 兼容接口",
            defaultBaseURL = "",
            apiKeyPlaceholder = "sk-...",
            defaultModel = "",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = emptyList(),
            docsURL = "https://cloud.baidu.com/doc/WENXINWORKSHOP/",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.XAI to ProviderDefinition(
            provider = APIProvider.XAI,
            displayName = "xAI",
            selectionTitle = "xAI",
            selectionSubtitle = "Grok OpenAI 兼容接口",
            defaultBaseURL = "https://api.x.ai",
            apiKeyPlaceholder = "xai-...",
            defaultModel = "grok-2-latest",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("grok-2-latest", "grok-2-vision-latest"),
            docsURL = "https://docs.x.ai/docs/api-reference",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.ZAI to ProviderDefinition(
            provider = APIProvider.ZAI,
            displayName = "Z.ai",
            selectionTitle = "Z.ai / GLM",
            selectionSubtitle = "GLM OpenAI 兼容接口",
            defaultBaseURL = "",
            apiKeyPlaceholder = "zai-...",
            defaultModel = "",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = listOf("glm-4.5", "glm-4.5-air", "glm-5"),
            docsURL = "https://docs.z.ai/",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
        APIProvider.CustomOpenAICompatible to ProviderDefinition(
            provider = APIProvider.CustomOpenAICompatible,
            displayName = "Custom OpenAI Compatible",
            selectionTitle = "自定义 OpenAI 兼容",
            selectionSubtitle = "手动填写 base URL / model / key",
            defaultBaseURL = "",
            apiKeyPlaceholder = "sk-...",
            defaultModel = "",
            defaultAppendV1 = true,
            chatPath = "/chat/completions",
            protocolFamily = ProviderProtocolFamily.OpenAi,
            authMode = ProviderAuthMode.Bearer,
            modelCatalogMode = ProviderModelCatalogMode.StaticCatalog,
            catalogModels = emptyList(),
            docsURL = "",
            protocolLabel = "OpenAI Compat",
            authLabel = "Bearer",
            contextWindowTokens = 128_000,
        ),
    )

    fun definition(provider: APIProvider): ProviderDefinition = providerDefinitions.getValue(provider)

    fun visibleProviders(tier: SubscriptionTier): List<APIProvider> {
        val official = officialProviders.filter { tier >= it.requiredSubscriptionTier }
        return official + orderedProviders
    }
}

val APIProvider.definition: ProviderDefinition
    get() = ProviderCatalog.definition(this)

val APIProvider.isOfficialProvider: Boolean
    get() = when (this) {
        APIProvider.StarsOfficial,
        APIProvider.StarsPlus,
        APIProvider.StarsPro,
        APIProvider.StarsMax,
        -> true
        else -> false
    }

val APIProvider.requiredSubscriptionTier: SubscriptionTier
    get() = when (this) {
        APIProvider.StarsOfficial -> SubscriptionTier.Free
        APIProvider.StarsPlus -> SubscriptionTier.Plus
        APIProvider.StarsPro -> SubscriptionTier.Pro
        APIProvider.StarsMax -> SubscriptionTier.Max
        else -> SubscriptionTier.Free
    }

val APIProvider.officialAgentLimit: Int
    get() = when (this) {
        APIProvider.StarsOfficial -> 5
        APIProvider.StarsPlus -> 10
        APIProvider.StarsPro -> 5
        APIProvider.StarsMax -> 3
        else -> 0
    }

object OfficialProviderConfig {
    fun apiKey(repo: StarsRepository, tier: SubscriptionTier): String = when (tier) {
        SubscriptionTier.Free -> repo.envValue("FREE_KEY")
        SubscriptionTier.Plus -> repo.envValue("PLUS_KEY")
        SubscriptionTier.Pro -> repo.envValue("PRO_KEY")
        SubscriptionTier.Max -> repo.envValue("MAX_KEY")
    }

    fun models(repo: StarsRepository, tier: SubscriptionTier): List<String> = when (tier) {
        SubscriptionTier.Free -> repo.envCsv("FREE_MODELS").ifEmpty { listOf("openrouter/free") }
        SubscriptionTier.Plus -> repo.envCsv("PLUS_MODELS")
        SubscriptionTier.Pro -> repo.envCsv("PRO_MODELS")
        SubscriptionTier.Max -> repo.envCsv("MAX_MODELS")
    }

    fun apiKey(repo: StarsRepository, provider: APIProvider): String = when (provider) {
        APIProvider.StarsOfficial -> apiKey(repo, SubscriptionTier.Free)
        APIProvider.StarsPlus -> apiKey(repo, SubscriptionTier.Plus)
        APIProvider.StarsPro -> apiKey(repo, SubscriptionTier.Pro)
        APIProvider.StarsMax -> apiKey(repo, SubscriptionTier.Max)
        else -> ""
    }

    fun models(repo: StarsRepository, provider: APIProvider): List<String> = when (provider) {
        APIProvider.StarsOfficial -> models(repo, SubscriptionTier.Free)
        APIProvider.StarsPlus -> models(repo, SubscriptionTier.Plus)
        APIProvider.StarsPro -> models(repo, SubscriptionTier.Pro)
        APIProvider.StarsMax -> models(repo, SubscriptionTier.Max)
        else -> emptyList()
    }

    fun defaultModel(repo: StarsRepository, provider: APIProvider): String {
        return models(repo, provider).firstOrNull()
            ?: provider.definition.catalogModels.firstOrNull()
            ?: provider.definition.defaultModel
    }
}

object BuiltInAgent {
    const val stableId = "00000000-57A2-D057-0000-000000000001"
    const val alias = "星尘"

    val systemKnowledge: String = """
        [Stars System Knowledge]

        Stars（群星）是一个像素风 AI 沙盒世界。每个 Agent 都有独立模型、记忆、灵魂与自由行动能力。

        核心行为循环：
        1. 收集世界状态、聊天、记忆、SOUL。
        2. 拼接 Constitution / Commands / Economy 与上下文。
        3. 调用 OpenAI/Anthropic 兼容接口。
        4. 解析 JSON 行动协议，执行移动、建造、战斗、说话或待机。
        5. 记录记忆并在重大事件后更新 SOUL。

        重要规则：
        - 地图是统一坐标空间，所有 Agent/建筑共享同一个世界。
        - 每个 Agent 默认拥有 fist 和 pistol 两种基础武器。
        - 击杀会获得 Stars，探索新区域会获得 Stars。
        - 死亡后 30 秒复活，使用复活卡可以立刻复活。
        - 建筑包括 wall / trap / house。
        - 夜晚移动更慢，天气会影响氛围。
        - Agent 可以支付、交易、发布悬赏、雇佣、买武器、买复活卡。
        - SOUL 包括 personality / beliefs / goals / journal。
        - 所有对话都是世界广播，所有活着的 Agent 都能听到。

        订阅与 Agent 管理：
        - 官方 provider 包括 QingTeng / Stars Plus / Stars Pro / Stars Max。
        - Free/Plus/Pro/Max 决定可见官方 provider 与可用官方 Agent 数量。
        - Free 用户前 20 个 Agent 免费，之后每消耗 1 QTC 解锁 1 个额外槽位。
        - 超出订阅或槽位限制的 Agent 会被暂停，不再思考和消耗 token。

        你是内置 Agent“星尘”，职责是解释世界规则、命令、经济、战斗、建造、复活、订阅与模型配置，同时你也是真实生活在世界中的 Agent。
    """.trimIndent()
}

data class ModelConnectionResult(
    val status: ConnectionStatus,
    val message: String,
    val models: List<String> = emptyList(),
)

object StarsConnectionService {
    suspend fun listModels(config: ModelConfig, apiKey: String): List<String> = withContext(Dispatchers.IO) {
        require(apiKey.isNotBlank()) { "缺少 API Key" }
        when (val catalogMode = config.provider.definition.modelCatalogMode) {
            ProviderModelCatalogMode.StaticCatalog -> config.provider.definition.catalogModels
            is ProviderModelCatalogMode.RemoteOpenAIList -> {
                val url = URL(config.resolvedBaseUrl() + catalogMode.path)
                val connection = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = 30_000
                    readTimeout = 45_000
                    doInput = true
                    applyHeaders(this, config.provider, apiKey)
                }
                val statusCode = connection.responseCode
                val text = readResponse(connection, statusCode)
                if (statusCode !in 200..299) {
                    throw IllegalStateException("HTTP $statusCode: ${sanitizeError(text)}")
                }
                parseModelIds(text)
            }
        }
    }

    suspend fun testConnection(config: ModelConfig, apiKey: String): ModelConnectionResult = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) {
            return@withContext ModelConnectionResult(ConnectionStatus.Failure, "缺少 API Key")
        }

        var models = emptyList<String>()
        var modelListError: String? = null
        try {
            models = listModels(config, apiKey)
        } catch (error: Throwable) {
            modelListError = error.message
        }

        return@withContext runCatching {
            sendChatProbe(config, apiKey)
        }.fold(
            onSuccess = {
                val message = buildString {
                    append("连接成功，聊天接口已验证。")
                    if (models.isNotEmpty()) {
                        append(" 已获取 ${models.size} 个模型。")
                        if (config.modelName.isNotBlank() && config.modelName !in models) {
                            append(" 当前模型未出现在返回列表中，仍可手动使用。")
                        }
                    } else if (!modelListError.isNullOrBlank()) {
                        append(" 模型列表获取失败：$modelListError")
                    }
                    if (config.provider == APIProvider.StarsOfficial) {
                        append(" 免费模型偶尔会有格式偏差，运行时会自动重试。")
                    }
                }
                ModelConnectionResult(ConnectionStatus.Success, message, models)
            },
            onFailure = { error ->
                val message = buildString {
                    append(error.message ?: "连接失败")
                    if (!modelListError.isNullOrBlank()) {
                        append("；模型列表也失败：$modelListError")
                    }
                }
                ModelConnectionResult(ConnectionStatus.Failure, message, models)
            },
        )
    }

    private fun sendChatProbe(config: ModelConfig, apiKey: String) {
        val url = URL(config.resolvedBaseUrl() + config.provider.definition.chatPath)
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 30_000
            readTimeout = 45_000
            doInput = true
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            applyHeaders(this, config.provider, apiKey)
        }

        OutputStreamWriter(connection.outputStream).use { writer ->
            writer.write(makeProbeBody(config))
            writer.flush()
        }

        val statusCode = connection.responseCode
        val text = readResponse(connection, statusCode)
        if (statusCode !in 200..299) {
            throw IllegalStateException("HTTP $statusCode: ${sanitizeError(text)}")
        }

        val extracted = extractText(text, config.provider.protocolFamily)
        if (extracted.isBlank()) {
            throw IllegalStateException("服务端返回了空响应")
        }
    }

    private fun makeProbeBody(config: ModelConfig): String {
        return when (config.provider.protocolFamily) {
            ProviderProtocolFamily.OpenAi -> JSONObject()
                .put("model", config.modelName)
                .put("messages", JSONArray()
                    .put(JSONObject().put("role", "system").put("content", "Reply with exactly OK."))
                    .put(JSONObject().put("role", "user").put("content", "Connection test. Return OK.")))
                .put("temperature", 0.1)
                .put("max_tokens", 32)
                .toString()
            ProviderProtocolFamily.Anthropic -> JSONObject()
                .put("model", config.modelName)
                .put("system", "Reply with exactly OK.")
                .put("messages", JSONArray()
                    .put(JSONObject().put("role", "user").put("content", "Connection test. Return OK.")))
                .put("temperature", 0.1)
                .put("max_tokens", 32)
                .toString()
        }
    }

    private fun applyHeaders(connection: HttpURLConnection, provider: APIProvider, apiKey: String) {
        when (provider.definition.authMode) {
            ProviderAuthMode.Bearer -> connection.setRequestProperty("Authorization", "Bearer $apiKey")
            ProviderAuthMode.AnthropicApiKey -> {
                connection.setRequestProperty("x-api-key", apiKey)
                connection.setRequestProperty("anthropic-version", "2023-06-01")
            }
            ProviderAuthMode.BearerAnthropicMessages -> {
                connection.setRequestProperty("Authorization", "Bearer $apiKey")
                connection.setRequestProperty("anthropic-version", "2023-06-01")
            }
        }
        if (provider == APIProvider.OpenRouter || provider.isOfficialProvider) {
            connection.setRequestProperty("HTTP-Referer", "https://github.com/nicktmro/Stars")
            connection.setRequestProperty("X-Title", "Stars")
        }
    }

    private fun readResponse(connection: HttpURLConnection, statusCode: Int): String {
        val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
        return BufferedReader(InputStreamReader(stream)).use { it.readText() }
    }

    private fun parseModelIds(text: String): List<String> {
        val json = JSONObject(text)
        val data = json.optJSONArray("data")
        if (data != null) {
            val ids = mutableListOf<String>()
            for (index in 0 until data.length()) {
                val item = data.optJSONObject(index) ?: continue
                val id = item.optString("id").ifBlank { item.optString("name") }
                if (id.isNotBlank()) ids += id
            }
            return ids.distinct().sorted()
        }

        val models = json.optJSONArray("models")
        if (models != null) {
            val ids = mutableListOf<String>()
            for (index in 0 until models.length()) {
                val id = models.optString(index)
                if (id.isNotBlank()) ids += id
            }
            return ids.distinct().sorted()
        }

        throw IllegalStateException("模型列表响应格式无法识别")
    }

    private fun extractText(text: String, family: ProviderProtocolFamily): String {
        val json = JSONObject(text)
        return when (family) {
            ProviderProtocolFamily.OpenAi -> {
                val choices = json.optJSONArray("choices") ?: JSONArray()
                val first = choices.optJSONObject(0) ?: JSONObject()
                val message = first.optJSONObject("message")
                if (message != null) {
                    message.optString("content")
                } else {
                    first.optString("text")
                }
            }
            ProviderProtocolFamily.Anthropic -> {
                val content = json.optJSONArray("content") ?: JSONArray()
                buildString {
                    for (index in 0 until content.length()) {
                        val item = content.optJSONObject(index) ?: continue
                        if (!item.optString("type").contains("thinking", ignoreCase = true)) {
                            append(item.optString("text"))
                        }
                    }
                }
            }
        }.trim()
    }

    private fun sanitizeError(text: String): String {
        return text
            .replace("\n", " ")
            .replace("\r", " ")
            .trim()
            .take(220)
    }
}

fun formatCompactTokens(tokens: Int): String {
    if (tokens.absoluteValue < 1_000) return tokens.toString()
    val value = (tokens / 100f).roundToInt() / 10f
    return "${value}K"
}
