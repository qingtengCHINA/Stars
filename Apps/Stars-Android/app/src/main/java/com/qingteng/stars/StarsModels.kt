package com.qingteng.stars

import androidx.compose.ui.graphics.Color
import kotlin.math.max
import kotlin.math.min

enum class AgentActionType {
    Idle,
    Move,
    Build,
    Attack,
    Talk,
}

enum class MemoryEventType {
    Combat,
    Build,
    Move,
    Talk,
    Observe,
}

enum class ChatSpeakerRole {
    Owner,
    Agent,
    System,
}

enum class KnowledgeCategory {
    Fact,
    Strategy,
    Event,
    Social,
    Location,
}

enum class WeatherEffect {
    Clear,
    Rain,
    HeavyRain,
    Snow,
    Thunderstorm,
    Fog,
}

enum class StructureType(
    val displayName: String,
    val buildCost: Int,
    val maxHp: Int,
) {
    Wall("wall", 2, 100),
    Trap("trap", 3, 30),
    House("house", 5, 150),
}

enum class WeaponCategory {
    Melee,
    Ranged,
    Explosive,
}

enum class ProviderProtocolFamily {
    OpenAi,
    Anthropic,
}

enum class ConnectionStatus {
    Unknown,
    Success,
    Failure,
    Paused,

    ;

    val displayText: String
        get() = when (this) {
            Unknown -> "未测试"
            Success -> "连接正常"
            Failure -> "连接失败"
            Paused -> "已暂停"
        }
}

enum class BgmSource {
    BuiltIn,
}

enum class TileType(
    val baseColor: Color,
    val altColor: Color,
    val detailColor: Color? = null,
) {
    DeepWater(
        Color(0xFF142E4D),
        Color(0xFF122847),
        Color(0xFF1F3F61),
    ),
    Water(
        Color(0xFF2E587F),
        Color(0xFF295273),
        Color(0xFF4C83A6),
    ),
    Sand(
        Color(0xFFB8A36E),
        Color(0xFFB09C68),
    ),
    Grass(
        Color(0xFF599B50),
        Color(0xFF528F4A),
    ),
    DarkGrass(
        Color(0xFF3D733B),
        Color(0xFF386C36),
    ),
    Flowers(
        Color(0xFFC9877B),
        Color(0xFFC17D71),
        Color(0xFFF5D75A),
    ),
    Dirt(
        Color(0xFF7A5E40),
        Color(0xFF72583A),
    ),
    Stone(
        Color(0xFF6B7075),
        Color(0xFF63686D),
    ),
}

enum class APIProvider(
    val displayName: String,
    val defaultBaseUrl: String,
    val defaultModel: String,
    val chatPath: String,
    val protocolFamily: ProviderProtocolFamily,
) {
    StarsOfficial("QingTeng Official", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    StarsPlus("Stars Plus", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    StarsPro("Stars Pro", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    StarsMax("Stars Max", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    OpenAI("OpenAI", "https://api.openai.com/v1", "gpt-4.1-mini", "/chat/completions", ProviderProtocolFamily.OpenAi),
    Anthropic("Anthropic", "https://api.anthropic.com", "claude-3-5-sonnet-latest", "/v1/messages", ProviderProtocolFamily.Anthropic),
    OpenRouter("OpenRouter", "https://openrouter.ai/api/v1", "openai/gpt-4.1-mini", "/chat/completions", ProviderProtocolFamily.OpenAi),
    MiniMax("MiniMax", "https://api.minimaxi.com/anthropic", "MiniMax-Text-01", "/v1/messages", ProviderProtocolFamily.Anthropic),
    Gemini("Gemini", "https://generativelanguage.googleapis.com/v1beta/openai", "gemini-2.0-flash", "/chat/completions", ProviderProtocolFamily.OpenAi),
    DeepSeek("DeepSeek", "https://api.deepseek.com/v1", "deepseek-chat", "/chat/completions", ProviderProtocolFamily.OpenAi),
    Moonshot("Moonshot", "https://api.moonshot.cn/v1", "moonshot-v1-8k", "/chat/completions", ProviderProtocolFamily.OpenAi),
    ModelStudio("ModelStudio", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    Groq("Groq", "https://api.groq.com/openai/v1", "llama-3.1-70b-versatile", "/chat/completions", ProviderProtocolFamily.OpenAi),
    Mistral("Mistral", "https://api.mistral.ai/v1", "mistral-small-latest", "/chat/completions", ProviderProtocolFamily.OpenAi),
    Perplexity("Perplexity", "https://api.perplexity.ai", "llama-3.1-sonar-small-128k-online", "/chat/completions", ProviderProtocolFamily.OpenAi),
    Ark("Ark", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    BigModel("BigModel", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    Hunyuan("Hunyuan", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    XiaomiMimo("Xiaomi MiMo", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    NvidiaNIM("NVIDIA NIM", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    InceptionLabs("Inception Labs", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    Qianfan("Qianfan", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    XAI("xAI", "https://api.x.ai/v1", "grok-2-latest", "/chat/completions", ProviderProtocolFamily.OpenAi),
    ZAI("Z.ai", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
    CustomOpenAICompatible("Custom OpenAI Compatible", "", "", "/chat/completions", ProviderProtocolFamily.OpenAi),
}

data class ModelConfig(
    val id: String,
    val alias: String,
    val provider: APIProvider,
    val baseUrl: String = "",
    val modelName: String = provider.defaultModel,
    val apiKey: String = "",
    val appendV1: Boolean = provider.definition.defaultAppendV1,
    val connectionStatus: ConnectionStatus = ConnectionStatus.Unknown,
    val connectionMessage: String? = null,
) {
    fun resolvedBaseUrl(): String {
        var value = (baseUrl.ifBlank { provider.definition.defaultBaseURL }).trim()
        while (value.endsWith("/")) {
            value = value.dropLast(1)
        }

        val removableSuffixes = listOf(
            provider.definition.chatPath,
            "/models",
        )
        removableSuffixes.forEach { suffix ->
            if (value.endsWith(suffix)) {
                value = value.dropLast(suffix.length)
                while (value.endsWith("/")) {
                    value = value.dropLast(1)
                }
            }
        }

        while (value.endsWith("/v1/v1")) {
            value = value.dropLast(3)
        }

        if (provider == APIProvider.MiniMax) {
            if (value == "https://api.minimaxi.com" || value == "https://api.minimaxi.com/") {
                return "https://api.minimaxi.com/anthropic/v1"
            }
            if (value.endsWith("/anthropic") && !value.endsWith("/anthropic/v1")) {
                return "$value/v1"
            }
        }

        return when {
            value.isBlank() -> value
            appendV1 && provider.definition.protocolFamily == ProviderProtocolFamily.OpenAi && !value.endsWith("/v1") -> "$value/v1"
            else -> value
        }
    }
}

data class MemoryEntry(
    val timestamp: Long,
    val type: MemoryEventType,
    val content: String,
)

data class ShortTermMessage(
    val speakerName: String,
    val content: String,
    val timestamp: Long,
)

data class ChatMessageEntry(
    val speaker: ChatSpeakerRole,
    val text: String,
    val timestamp: Long,
)

data class StarTransaction(
    val timestamp: Long,
    val amount: Int,
    val reason: String,
    val balance: Int,
)

data class KnowledgeEntry(
    val category: KnowledgeCategory,
    val content: String,
    val importance: Int = 3,
    val createdAt: Long = System.currentTimeMillis(),
    val lastRecalled: Long = createdAt,
    val recallCount: Int = 0,
)

data class SoulDocument(
    val personality: String = "",
    val beliefs: String = "",
    val goals: String = "",
    val journal: String = "",
    val lastUpdated: Long = System.currentTimeMillis(),
) {
    fun promptSection(): String {
        if (personality.isBlank() && beliefs.isBlank() && goals.isBlank() && journal.isBlank()) {
            return """
                === YOUR SOUL ===
                You have not yet formed your SOUL. Reflect after meaningful experiences.
                === END SOUL ===
            """.trimIndent()
        }
        return buildString {
            appendLine("=== YOUR SOUL ===")
            if (personality.isNotBlank()) appendLine("Personality: $personality")
            if (beliefs.isNotBlank()) appendLine("Beliefs: $beliefs")
            if (goals.isNotBlank()) appendLine("Goals: $goals")
            if (journal.isNotBlank()) appendLine("Journal: $journal")
            append("=== END SOUL ===")
        }
    }
}

data class CommandAliasProposal(
    val name: String,
    val basedOn: String,
    val description: String,
)

data class WorldCommandDescriptor(
    val name: String,
    val action: AgentActionType,
    val description: String,
    val defaultBuildType: StructureType? = null,
    val defaultWeapon: String? = null,
)

data class ResolvedWorldCommand(
    val name: String,
    val action: AgentActionType,
    val defaultBuildType: StructureType? = null,
    val defaultWeapon: String? = null,
)

data class AgentTarget(
    val x: Int? = null,
    val y: Int? = null,
    val entityID: String? = null,
    val buildType: String? = null,
    val weapon: String? = null,
    val starsAmount: Int? = null,
    val recipientID: String? = null,
)

data class SoulReflection(
    val personality: String? = null,
    val beliefs: String? = null,
    val goals: String? = null,
    val journal: String? = null,
)

data class LlmResponse(
    val thought: String = "",
    val command: String? = null,
    val action: String = "idle",
    val target: AgentTarget? = null,
    val speech: String? = null,
    val customCommand: CommandAliasProposal? = null,
    val soulReflection: SoulReflection? = null,
)

data class PendingBuild(
    val type: StructureType,
    val tileX: Int,
    val tileY: Int,
)

data class ContextUsageSnapshot(
    val usedTokens: Int,
    val limitTokens: Int,
    val didCompact: Boolean = false,
    val compactedMemoryEntries: Int = 0,
    val compactedChatMessages: Int = 0,
    val responseTokens: Int = 0,
) {
    val usageRatio: Float
        get() = if (limitTokens <= 0) 0f else usedTokens.toFloat() / limitTokens.toFloat()

    val percentageText: String
        get() = "${(usageRatio * 100f).coerceIn(0f, 999f).toInt()}%"
}

data class WeaponDefinition(
    val id: String,
    val displayName: String,
    val category: WeaponCategory,
    val damage: Int,
    val cooldown: Float,
    val cost: Int,
    val reach: Float,
    val speed: Float,
    val aoeRadius: Float,
    val pellets: Int,
    val spreadAngle: Float,
    val color: Color,
    val projectileSize: Int,
    val ammoPerPurchase: Int,
    val isHoming: Boolean = false,
)

data class TradeOffer(
    val id: String,
    val offerorID: String,
    val offerorName: String,
    val recipientID: String,
    val recipientName: String,
    val starsAmount: Int,
    val description: String,
    val createdAt: Long = System.currentTimeMillis(),
)

data class Bounty(
    val id: String,
    val posterID: String,
    val posterName: String,
    val targetID: String,
    val targetName: String,
    val reward: Int,
    val reason: String,
    val createdAt: Long = System.currentTimeMillis(),
)

data class StructureEntity(
    val id: String,
    val type: StructureType,
    val tileX: Int,
    val tileY: Int,
    val hp: Int = type.maxHp,
    val ownerID: String? = null,
)

data class ProjectileEntity(
    val id: String,
    val ownerID: String,
    val weaponId: String,
    val x: Float,
    val y: Float,
    val dx: Float,
    val dy: Float,
    val speed: Float,
    val damage: Int,
    val aoeRadius: Float,
    val ttl: Float = 3f,
    val homingTargetId: String? = null,
    val isHoming: Boolean = false,
)

data class AgentEntity(
    val entityID: String,
    val displayName: String,
    val modelConfigID: String? = null,
    val agentColorArgb: Int,
    val x: Float,
    val y: Float,
    val hp: Int = 100,
    val maxHp: Int = 100,
    val moveSpeed: Float = 30f,
    val currentThought: String? = null,
    val currentAction: AgentActionType = AgentActionType.Idle,
    val targetX: Float? = null,
    val targetY: Float? = null,
    val pendingBuild: PendingBuild? = null,
    val buildProgressSeconds: Float = 0f,
    val pendingWeaponId: String = "fist",
    val weaponCooldown: Float = 0f,
    val buildCooldown: Float = 0f,
    val stars: Int = 0,
    val starTransactions: List<StarTransaction> = emptyList(),
    val memories: List<MemoryEntry> = emptyList(),
    val shortTermMessages: List<ShortTermMessage> = emptyList(),
    val chatMessages: List<ChatMessageEntry> = emptyList(),
    val longTermMemories: List<KnowledgeEntry> = emptyList(),
    val soul: SoulDocument = SoulDocument(),
    val pendingOwnerReplies: Int = 0,
    val forceNextThink: Boolean = false,
    val latestContextUsage: ContextUsageSnapshot? = null,
    val totalTokensUsed: Int = 0,
    val thinkCycleCount: Int = 0,
    val isThinking: Boolean = false,
    val nextThinkAtMs: Long = 0L,
    val consecutiveFailures: Int = 0,
    val respawnRemaining: Float = 0f,
    val houseRestAccumulator: Float = 0f,
    val isRestingInHouse: Boolean = false,
    val speechText: String? = null,
    val speechUntilMs: Long = 0L,
    val visitedChunks: Set<String> = emptySet(),
    val weaponAmmo: Map<String, Int> = emptyMap(),
    val revivalCards: Int = 0,
    val wanderIdle: Boolean = true,
    val wanderTimer: Float = 0.5f,
    val wanderDx: Float = 0f,
    val wanderDy: Float = 0f,
    val facingAngle: Float = 0f,
    val isBuiltIn: Boolean = false,
) {
    val isDead: Boolean
        get() = hp <= 0

    val isNearDeath: Boolean
        get() = !isDead && hp in 1..5
}

data class CameraSnapshot(
    val x: Float,
    val y: Float,
    val scale: Float,
)

data class GameSnapshot(
    val savedAt: Long,
    val agents: List<AgentEntity>,
    val structures: List<StructureEntity>,
    val camera: CameraSnapshot,
    val customCommands: List<CommandAliasProposal> = emptyList(),
    val dayOffset: Int = 0,
    val pendingTrades: List<TradeOffer> = emptyList(),
    val bounties: List<Bounty> = emptyList(),
)

object StarsDefaults {
    const val TileSize = 16f
    const val AgentSize = 24f
    const val ChunkTileCount = 16
    const val ChunkWorldSize = TileSize * ChunkTileCount
    const val BuiltInGuideId = BuiltInAgent.stableId

    val ProviderList: List<APIProvider> = APIProvider.entries

    val BuiltInGuideText = """
        You are 星尘 (Stardust), the built-in guide of Stars.
        Explain commands, economy, combat, weather, building, respawn, and model setup.
        You are also a normal citizen of the world and may explore, talk, build, and fight.
    """.trimIndent()

    val Constitution = """
        Stars is a pixel-art AI sandbox world.
        Agents have free will.
        The constitution defines rules, not emotions.
        Combat, building, diplomacy, economy, death, and revival are all allowed.
        Owner messages are high-priority instructions whenever feasible.
    """.trimIndent()

    val Commands = """
        Idle: /idle /hold /observe /rest /guard
        Move: /move /goto /explore /scout /patrol /defense /retreat /flee /enter_house /follow
        Talk: /talk /report /respond /wave /ally /treaty /challenge /warn
        Build: /build_wall /build_trap /build_house /fortify
        Attack: /attack_melee /attack_ranged /harass /demolish
        Economy: /pay /offer_trade /accept_trade /decline_trade /bounty /cancel_bounty /hire /buy_weapon /buy_revival /revive
        Always return a single JSON object with thought, command, action, speech, target, customCommand, soulReflection.
    """.trimIndent()

    val Economy = """
        Stars are the universal currency.
        Earn stars by exploration and kills.
        Building costs: wall=2, trap=3, house=5.
        Trade offers escrow stars until accepted or declined.
        Bounties are public and stack.
        Revival cards cost 150 stars.

        [CONFIG]
        kill_reward = 1
        kill_reward_percent = 50
        exploration_reward = 1
        wall_cost = 2
        trap_cost = 3
        house_cost = 5
        wall_hp = 100
        trap_hp = 30
        trap_damage = 25
        house_hp = 150
        revival_card_cost = 150
        system_bounty_reward = 10
        max_bounties_per_agent = 3
        trade_expiration = 300
        respawn_time = 30
        house_rest_hp_threshold = 50
        house_rest_heal = 5
        [/CONFIG]
    """.trimIndent()

    val About = """
        Stars · 群星

        一个像素风 AI 沙盒世界。每个 Agent 由大语言模型驱动，拥有独立记忆、灵魂和自由意志。

        Android 端复刻目标：
        - 保持无限 2D 像素世界
        - 保持 Agent 自主思考、战斗、建造、交易与社交
        - 保持房屋休息、复活卡、悬赏、排行榜、音频与存档
        - 保持 Owner 聊天驱动和模型配置能力
    """.trimIndent()
}

data class EconomyConfig(
    val killReward: Int = 1,
    val killRewardPercent: Int = 50,
    val explorationReward: Int = 1,
    val wallCost: Int = 2,
    val trapCost: Int = 3,
    val houseCost: Int = 5,
    val wallHp: Int = 100,
    val trapHp: Int = 30,
    val trapDamage: Int = 25,
    val houseHp: Int = 150,
    val revivalCardCost: Int = 150,
    val systemBountyReward: Int = 10,
    val maxBountiesPerAgent: Int = 3,
    val tradeExpirationSeconds: Int = 300,
    val respawnTimeSeconds: Int = 30,
    val houseRestHpThreshold: Int = 50,
    val houseRestHealAmount: Int = 5,
) {
    companion object {
        fun parse(text: String): EconomyConfig {
            val defaults = EconomyConfig()
            val configBlock = text.substringAfter("[CONFIG]", "").substringBefore("[/CONFIG]", "")
            if (configBlock.isBlank()) {
                return defaults
            }
            val map = mutableMapOf<String, String>()
            configBlock.lineSequence()
                .map { it.trim() }
                .filter { it.isNotEmpty() && !it.startsWith("#") && !it.startsWith("//") }
                .forEach { line ->
                    val parts = line.split("=", limit = 2)
                    if (parts.size == 2) {
                        map[parts[0].trim().lowercase()] = parts[1].trim()
                    }
                }
            fun intValue(key: String, fallback: Int): Int = map[key]?.toIntOrNull() ?: fallback
            return EconomyConfig(
                killReward = intValue("kill_reward", defaults.killReward),
                killRewardPercent = intValue("kill_reward_percent", defaults.killRewardPercent).coerceIn(0, 100),
                explorationReward = intValue("exploration_reward", defaults.explorationReward),
                wallCost = intValue("wall_cost", defaults.wallCost),
                trapCost = intValue("trap_cost", defaults.trapCost),
                houseCost = intValue("house_cost", defaults.houseCost),
                wallHp = intValue("wall_hp", defaults.wallHp),
                trapHp = intValue("trap_hp", defaults.trapHp),
                trapDamage = intValue("trap_damage", defaults.trapDamage),
                houseHp = intValue("house_hp", defaults.houseHp),
                revivalCardCost = intValue("revival_card_cost", defaults.revivalCardCost),
                systemBountyReward = intValue("system_bounty_reward", defaults.systemBountyReward),
                maxBountiesPerAgent = max(1, intValue("max_bounties_per_agent", defaults.maxBountiesPerAgent)),
                tradeExpirationSeconds = intValue("trade_expiration", defaults.tradeExpirationSeconds),
                respawnTimeSeconds = intValue("respawn_time", defaults.respawnTimeSeconds),
                houseRestHpThreshold = intValue("house_rest_hp_threshold", defaults.houseRestHpThreshold),
                houseRestHealAmount = intValue("house_rest_heal", defaults.houseRestHealAmount),
            )
        }
    }
}

fun Int.toClampedImportance(): Int = min(5, max(1, this))
