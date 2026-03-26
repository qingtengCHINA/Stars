package com.qingteng.stars

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.google.gson.Gson
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

private data class RegisteredCustomCommand(
    val proposal: CommandAliasProposal,
    val descriptor: WorldCommandDescriptor,
)

class WorldCommandRegistry {
    private val builtin: Map<String, WorldCommandDescriptor> = listOf(
        WorldCommandDescriptor("/idle", AgentActionType.Idle, "Stand still."),
        WorldCommandDescriptor("/hold", AgentActionType.Idle, "Hold current position."),
        WorldCommandDescriptor("/observe", AgentActionType.Idle, "Pause and observe."),
        WorldCommandDescriptor("/rest", AgentActionType.Idle, "Return to your own house and rest."),
        WorldCommandDescriptor("/guard", AgentActionType.Idle, "Guard the current area."),
        WorldCommandDescriptor("/move", AgentActionType.Move, "Move to a tile."),
        WorldCommandDescriptor("/goto", AgentActionType.Move, "Travel directly to a tile."),
        WorldCommandDescriptor("/explore", AgentActionType.Move, "Explore new territory."),
        WorldCommandDescriptor("/scout", AgentActionType.Move, "Scout the area."),
        WorldCommandDescriptor("/patrol", AgentActionType.Move, "Patrol an area."),
        WorldCommandDescriptor("/defense", AgentActionType.Move, "Tactical repositioning."),
        WorldCommandDescriptor("/retreat", AgentActionType.Move, "Retreat to safety."),
        WorldCommandDescriptor("/flee", AgentActionType.Move, "Emergency escape."),
        WorldCommandDescriptor("/enter_house", AgentActionType.Move, "Go to your house."),
        WorldCommandDescriptor("/follow", AgentActionType.Move, "Follow another agent."),
        WorldCommandDescriptor("/talk", AgentActionType.Talk, "Speak aloud."),
        WorldCommandDescriptor("/report", AgentActionType.Talk, "Report findings."),
        WorldCommandDescriptor("/respond", AgentActionType.Talk, "Reply to what you heard."),
        WorldCommandDescriptor("/wave", AgentActionType.Talk, "Friendly greeting."),
        WorldCommandDescriptor("/ally", AgentActionType.Talk, "Propose an alliance."),
        WorldCommandDescriptor("/treaty", AgentActionType.Talk, "Formal treaty."),
        WorldCommandDescriptor("/challenge", AgentActionType.Talk, "Threaten or provoke."),
        WorldCommandDescriptor("/warn", AgentActionType.Talk, "Warn about danger."),
        WorldCommandDescriptor("/build_wall", AgentActionType.Build, "Build a wall.", StructureType.Wall),
        WorldCommandDescriptor("/build_trap", AgentActionType.Build, "Build a trap.", StructureType.Trap),
        WorldCommandDescriptor("/build_house", AgentActionType.Build, "Build a house.", StructureType.House),
        WorldCommandDescriptor("/fortify", AgentActionType.Build, "Build defenses.", StructureType.Wall),
        WorldCommandDescriptor("/attack_melee", AgentActionType.Attack, "Melee attack.", defaultWeapon = "fist"),
        WorldCommandDescriptor("/attack_ranged", AgentActionType.Attack, "Ranged attack.", defaultWeapon = "pistol"),
        WorldCommandDescriptor("/harass", AgentActionType.Attack, "Mobile ranged pressure.", defaultWeapon = "pistol"),
        WorldCommandDescriptor("/demolish", AgentActionType.Attack, "Destroy a structure.", defaultWeapon = "fist"),
        WorldCommandDescriptor("/pay", AgentActionType.Talk, "Send stars."),
        WorldCommandDescriptor("/offer_trade", AgentActionType.Talk, "Offer stars for a task."),
        WorldCommandDescriptor("/accept_trade", AgentActionType.Talk, "Accept a trade."),
        WorldCommandDescriptor("/decline_trade", AgentActionType.Talk, "Decline a trade."),
        WorldCommandDescriptor("/bounty", AgentActionType.Talk, "Post a bounty."),
        WorldCommandDescriptor("/cancel_bounty", AgentActionType.Talk, "Cancel a bounty."),
        WorldCommandDescriptor("/hire", AgentActionType.Talk, "Hire another agent."),
        WorldCommandDescriptor("/buy_weapon", AgentActionType.Talk, "Buy weapon ammo."),
        WorldCommandDescriptor("/buy_revival", AgentActionType.Talk, "Buy a revival card."),
        WorldCommandDescriptor("/revive", AgentActionType.Talk, "Use a revival card."),
    ).associateBy { it.name }

    private val custom = linkedMapOf<String, RegisteredCustomCommand>()

    private fun descriptorFor(name: String): WorldCommandDescriptor? {
        return custom[name]?.descriptor ?: builtin[name]
    }

    fun resolve(name: String?, fallback: AgentActionType): ResolvedWorldCommand {
        val descriptor = name?.let(::descriptorFor)
        if (descriptor != null) {
            return ResolvedWorldCommand(
                name = descriptor.name,
                action = descriptor.action,
                defaultBuildType = descriptor.defaultBuildType,
                defaultWeapon = descriptor.defaultWeapon,
            )
        }
        return when (fallback) {
            AgentActionType.Idle -> ResolvedWorldCommand("/idle", AgentActionType.Idle)
            AgentActionType.Move -> ResolvedWorldCommand("/move", AgentActionType.Move)
            AgentActionType.Build -> ResolvedWorldCommand("/build_wall", AgentActionType.Build, StructureType.Wall)
            AgentActionType.Attack -> ResolvedWorldCommand("/attack_melee", AgentActionType.Attack, defaultWeapon = "fist")
            AgentActionType.Talk -> ResolvedWorldCommand("/talk", AgentActionType.Talk)
        }
    }

    fun registerAliasIfSafe(proposal: CommandAliasProposal): Boolean {
        val name = proposal.name.trim()
        val base = proposal.basedOn.trim()
        val description = proposal.description.trim()
        if (!name.startsWith("/") || name.length > 24 || description.isBlank() || description.length > 80) {
            return false
        }
        if (builtin.containsKey(name) || custom.containsKey(name)) {
            return false
        }
        val baseDescriptor = descriptorFor(base) ?: return false
        custom[name] = RegisteredCustomCommand(
            proposal = CommandAliasProposal(
                name = name,
                basedOn = base,
                description = description,
            ),
            descriptor = baseDescriptor.copy(name = name, description = description),
        )
        return true
    }

    fun restore(proposals: List<CommandAliasProposal>) {
        custom.clear()
        proposals.forEach { registerAliasIfSafe(it) }
    }

    fun customCommands(): List<CommandAliasProposal> {
        return custom.values.map { it.proposal }
    }

    fun promptSection(): String {
        val lines = (builtin.values + custom.values.map { it.descriptor })
            .sortedBy { it.name }
            .joinToString("\n") { "- ${it.name}: ${it.description}" }
        return """
            World commands:
            $lines

            You may define one safe custom alias via customCommand.
            It must start with "/" and must be based on an existing command only.
        """.trimIndent()
    }
}

object WeaponCatalog {
    val defaultWeapons = setOf("fist", "pistol")

    val weapons: List<WeaponDefinition> = listOf(
        WeaponDefinition("fist", "Fist / 拳头", WeaponCategory.Melee, 8, 0.6f, 0, 14f, 0f, 0f, 1, 0f, Color.White, 0, 0),
        WeaponDefinition("sword", "Sword / 剑", WeaponCategory.Melee, 15, 0.8f, 3, 18f, 0f, 0f, 1, 0f, Color(0xFFD9D9E3), 0, 12),
        WeaponDefinition("axe", "Axe / 斧头", WeaponCategory.Melee, 22, 1.2f, 5, 14f, 0f, 0f, 1, 0f, Color(0xFF996633), 0, 8),
        WeaponDefinition("spear", "Spear / 长矛", WeaponCategory.Melee, 12, 0.9f, 4, 24f, 0f, 0f, 1, 0f, Color(0xFFB38C59), 0, 10),
        WeaponDefinition("chainsaw", "Chainsaw / 电锯", WeaponCategory.Melee, 28, 1.5f, 8, 16f, 0f, 0f, 1, 0f, Color(0xFFCC3333), 0, 6),
        WeaponDefinition("pistol", "Pistol / 手枪", WeaponCategory.Ranged, 8, 0.8f, 0, 80f, 120f, 0f, 1, 0f, Color(0xFFFFF24D), 2, 0),
        WeaponDefinition("rifle", "Rifle / 步枪", WeaponCategory.Ranged, 15, 1.0f, 5, 130f, 160f, 0f, 1, 0f, Color(0xFFFFB333), 3, 15),
        WeaponDefinition("shotgun", "Shotgun / 霰弹枪", WeaponCategory.Ranged, 7, 1.5f, 6, 50f, 100f, 0f, 5, 30f, Color(0xFFFF5533), 2, 10),
        WeaponDefinition("smg", "SMG / 冲锋枪", WeaponCategory.Ranged, 6, 0.25f, 4, 80f, 140f, 0f, 1, 0f, Color(0xFFFFE166), 2, 20),
        WeaponDefinition("sniper", "Sniper / 狙击枪", WeaponCategory.Ranged, 35, 2.5f, 10, 220f, 250f, 0f, 1, 0f, Color.White, 3, 8),
        WeaponDefinition("crossbow", "Crossbow / 弩", WeaponCategory.Ranged, 12, 1.2f, 3, 100f, 90f, 0f, 1, 0f, Color(0xFF997347), 3, 12),
        WeaponDefinition("grenade", "Grenade / 手雷", WeaponCategory.Explosive, 20, 3.0f, 5, 60f, 80f, 30f, 1, 0f, Color(0xFF338033), 3, 5),
        WeaponDefinition("rocket_launcher", "Rocket / 火箭弹", WeaponCategory.Explosive, 25, 3.0f, 10, 130f, 100f, 35f, 1, 0f, Color(0xFFFF661A), 4, 4, isHoming = true),
        WeaponDefinition("missile", "Missile / 导弹", WeaponCategory.Explosive, 40, 5.0f, 18, 180f, 130f, 45f, 1, 0f, Color(0xFFE6261A), 5, 3, isHoming = true),
        WeaponDefinition("mortar", "Mortar / 迫击炮", WeaponCategory.Explosive, 30, 4.0f, 12, 160f, 70f, 45f, 1, 0f, Color(0xFF805933), 4, 4),
        WeaponDefinition("plasma_cannon", "Plasma Cannon / 等离子炮", WeaponCategory.Explosive, 45, 4.0f, 22, 140f, 90f, 40f, 1, 0f, Color(0xFF9933E6), 5, 3),
        WeaponDefinition("laser", "Laser / 激光枪", WeaponCategory.Ranged, 20, 0.5f, 15, 180f, 350f, 0f, 1, 0f, Color.Cyan, 2, 10),
        WeaponDefinition("flamethrower", "Flamethrower / 火焰喷射器", WeaponCategory.Ranged, 6, 0.5f, 8, 45f, 60f, 0f, 3, 25f, Color(0xFFFF7A00), 3, 8),
        WeaponDefinition("poison_dart", "Poison Dart / 毒镖", WeaponCategory.Ranged, 18, 2.0f, 4, 90f, 110f, 0f, 1, 0f, Color(0xFF55D93D), 2, 8),
        WeaponDefinition("landmine", "Landmine / 地雷", WeaponCategory.Melee, 35, 2.0f, 5, 14f, 0f, 25f, 1, 0f, Color(0xFF666666), 0, 3),
        WeaponDefinition("claymore", "Claymore / 阔剑地雷", WeaponCategory.Melee, 25, 2.0f, 4, 14f, 0f, 20f, 1, 0f, Color(0xFF59604D), 0, 3),
        WeaponDefinition("drone_strike", "Drone Strike / 无人机打击", WeaponCategory.Explosive, 50, 10.0f, 25, 250f, 200f, 50f, 1, 0f, Color(0xFFE6E6E6), 4, 2, isHoming = true),
    )

    private val byId = weapons.associateBy { it.id }

    fun weapon(id: String): WeaponDefinition = byId[id] ?: byId.getValue("fist")

    fun inventoryPrompt(agent: AgentEntity): String {
        val owned = weapons.filter { it.id in defaultWeapons || (agent.weaponAmmo[it.id] ?: 0) > 0 }
        if (owned.isEmpty()) return ""
        return buildString {
            appendLine("Your weapons:")
            owned.forEach { weapon ->
                val ammo = if (weapon.id in defaultWeapons) "∞" else (agent.weaponAmmo[weapon.id] ?: 0).toString()
                appendLine("  - ${weapon.id} [${weapon.category.name.lowercase()}] ${weapon.damage}dmg CD${"%.1f".format(weapon.cooldown)} ammo:$ammo")
            }
        }.trim()
    }

    fun shopPrompt(stars: Int): String {
        return buildString {
            appendLine("Weapon Shop (/buy_weapon):")
            weapons.filter { it.cost > 0 }.sortedBy { it.cost }.take(12).forEach { weapon ->
                val tag = if (stars >= weapon.cost) "✅" else "❌"
                appendLine("  $tag ${weapon.id}: ${weapon.cost}⭐ ${weapon.damage}dmg CD${"%.1f".format(weapon.cooldown)} ammo=${weapon.ammoPerPurchase}")
            }
        }.trim()
    }
}

object TerrainGenerator {
    fun tileAt(worldX: Int, worldY: Int): TileType {
        handcraftedSpawnTile(worldX, worldY)?.let { return it }
        val x = worldX.toDouble()
        val y = worldY.toDouble()
        val macro = fbm(x, y, seed = 11, scale = 110.0, octaves = 4)
        val moisture = fbm(x + 1900.0, y - 2400.0, seed = 23, scale = 62.0, octaves = 3)
        val richness = fbm(x - 900.0, y + 1200.0, seed = 31, scale = 24.0, octaves = 3)
        val ridge = ridgedFbm(x + 600.0, y - 300.0, seed = 71, scale = 54.0, octaves = 3)
        val trail = kotlin.math.abs(fbm(x + 4400.0, y - 1700.0, seed = 97, scale = 34.0, octaves = 2) - 0.5)
        if (trail < 0.028 && macro > 0.28 && macro < 0.82) {
            return if (moisture > 0.58) TileType.Dirt else TileType.Sand
        }
        if (macro < 0.18) return TileType.DeepWater
        if (macro < 0.26) return TileType.Water
        if (macro < 0.31) return TileType.Sand
        if (ridge > 0.78 && macro > 0.56) return TileType.Stone
        if (macro > 0.84) return if (richness > 0.58) TileType.Stone else TileType.Dirt
        if (moisture > 0.74) return if (richness > 0.62) TileType.Flowers else TileType.DarkGrass
        if (richness > 0.68 && moisture > 0.46) return TileType.Flowers
        if (richness < 0.22 && macro > 0.60) return TileType.Dirt
        if (macro > 0.63) return TileType.DarkGrass
        return TileType.Grass
    }

    private fun handcraftedSpawnTile(worldX: Int, worldY: Int): TileType? {
        val dx = worldX - 8
        val dy = worldY - 8
        val distance = hypot(dx.toDouble(), dy.toDouble())
        if (abs(dx) > 18 || abs(dy) > 14) return null
        if (distance < 5) return TileType.Grass
        if (abs(dx) <= 1 || abs(dy) <= 1) return if (distance < 13) TileType.Sand else TileType.Dirt
        if (distance > 14 && distance < 16) return TileType.DarkGrass
        if (distance >= 16) return if (abs(dx + dy) % 5 == 0) TileType.Flowers else TileType.Grass
        return TileType.Grass
    }

    private fun fbm(x: Double, y: Double, seed: Int, scale: Double, octaves: Int): Double {
        var total = 0.0
        var amplitude = 0.5
        var frequency = 1.0
        var normalization = 0.0
        repeat(octaves) { octave ->
            total += amplitude * smoothNoise(x / scale * frequency, y / scale * frequency, seed + octave * 997)
            normalization += amplitude
            amplitude *= 0.5
            frequency *= 2.0
        }
        return total / max(normalization, 0.0001)
    }

    private fun ridgedFbm(x: Double, y: Double, seed: Int, scale: Double, octaves: Int): Double {
        val value = fbm(x, y, seed, scale, octaves)
        return 1.0 - kotlin.math.abs(value * 2.0 - 1.0)
    }

    private fun smoothNoise(x: Double, y: Double, seed: Int): Double {
        val x0 = floor(x).toInt()
        val y0 = floor(y).toInt()
        val x1 = x0 + 1
        val y1 = y0 + 1
        val tx = smoothstep(x - floor(x))
        val ty = smoothstep(y - floor(y))
        val n00 = hashNoise(x0, y0, seed)
        val n10 = hashNoise(x1, y0, seed)
        val n01 = hashNoise(x0, y1, seed)
        val n11 = hashNoise(x1, y1, seed)
        val nx0 = lerp(n00, n10, tx)
        val nx1 = lerp(n01, n11, tx)
        return lerp(nx0, nx1, ty)
    }

    private fun hashNoise(x: Int, y: Int, seed: Int): Double {
        var value = x.toLong() * 374_761_393L
        value += y.toLong() * 668_265_263L
        value += seed.toLong() * 1_442_695_040L
        value = (value xor (value shr 13)) * 1_274_126_177L
        value = value xor (value shr 16)
        return (value and 0x7fff_ffff).toDouble() / Int.MAX_VALUE.toDouble()
    }

    private fun smoothstep(t: Double): Double = t * t * (3.0 - 2.0 * t)
    private fun lerp(a: Double, b: Double, t: Double): Double = a + (b - a) * t
}

object LlmService {
    private val gson = Gson()

    suspend fun sendPrompt(
        prompt: String,
        config: ModelConfig,
        apiKey: String,
    ): Pair<LlmResponse, String> = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) {
            throw IllegalStateException("Missing API key")
        }
        val endpoint = config.resolvedBaseUrl() + config.provider.definition.chatPath
        val url = URL(endpoint)
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doInput = true
            doOutput = true
            connectTimeout = 45_000
            readTimeout = 90_000
            setRequestProperty("Content-Type", "application/json")
            applyHeaders(this, config.provider, apiKey)
        }

        val body = when (config.provider.protocolFamily) {
            ProviderProtocolFamily.OpenAi -> JSONObject()
                .put("model", config.modelName)
                .put("messages", JSONArray()
                    .put(JSONObject().put("role", "system").put("content", "You are an AI agent in Stars. Respond with exactly one JSON object."))
                    .put(JSONObject().put("role", "user").put("content", prompt)))
                .put("temperature", 0.8)
                .put("max_tokens", 1200)
                .toString()
            ProviderProtocolFamily.Anthropic -> JSONObject()
                .put("model", config.modelName)
                .put("system", "You are an AI agent in Stars. Respond with exactly one JSON object.")
                .put("messages", JSONArray().put(JSONObject().put("role", "user").put("content", prompt)))
                .put("temperature", 0.8)
                .put("max_tokens", 1200)
                .toString()
        }

        OutputStreamWriter(connection.outputStream).use { writer ->
            writer.write(body)
            writer.flush()
        }

        val code = connection.responseCode
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val responseText = BufferedReader(InputStreamReader(stream)).use { it.readText() }
        if (code !in 200..299) {
            throw IllegalStateException("HTTP $code: ${responseText.take(220)}")
        }
        val assistantText = extractText(responseText, config.provider.protocolFamily)
        gson.fromJson(extractJsonObject(assistantText), LlmResponse::class.java) to assistantText
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

    private fun extractText(raw: String, family: ProviderProtocolFamily): String {
        val json = JSONObject(raw)
        return when (family) {
            ProviderProtocolFamily.OpenAi -> {
                val choices = json.optJSONArray("choices") ?: JSONArray()
                val first = choices.optJSONObject(0) ?: JSONObject()
                val message = first.optJSONObject("message")
                val content = message?.opt("content")
                when (content) {
                    is String -> content
                    is JSONArray -> buildString {
                        for (i in 0 until content.length()) {
                            val item = content.optJSONObject(i)
                            append(item?.optString("text") ?: "")
                        }
                    }
                    else -> first.optString("text", json.optString("output_text"))
                }
            }
            ProviderProtocolFamily.Anthropic -> {
                val content = json.optJSONArray("content") ?: JSONArray()
                buildString {
                    for (i in 0 until content.length()) {
                        val item = content.optJSONObject(i) ?: continue
                        if (item.optString("type").contains("thinking", ignoreCase = true)) continue
                        append(item.optString("text"))
                    }
                }
            }
        }.trim()
    }

    private fun extractJsonObject(text: String): String {
        var raw = text.trim()
        if (raw.contains("```")) {
            raw = raw
                .replace("```json", "")
                .replace("```", "")
                .trim()
        }
        val start = raw.indexOf('{')
        val end = raw.lastIndexOf('}')
        if (start >= 0 && end > start) {
            return raw.substring(start, end + 1)
        }
        throw IllegalStateException("No JSON object in model response")
    }
}

class StarsEngine(
    private val repo: StarsRepository,
    private val scope: CoroutineScope,
) {
    private val gson = Gson()
    private val random = Random(System.currentTimeMillis())
    private val commandRegistry = WorldCommandRegistry()

    var modelConfigs by mutableStateOf(repo.loadModels())
        private set
    var subscriptionTier by mutableStateOf(repo.loadSubscriptionTier())
        private set
    var qtcState by mutableStateOf(repo.loadQtcState())
        private set
    var constitution by mutableStateOf(repo.loadConstitution())
        private set
    var commandsText by mutableStateOf(repo.loadCommands())
        private set
    var economyText by mutableStateOf(repo.loadEconomy())
        private set
    var aboutText by mutableStateOf(repo.loadAbout())
        private set
    var economyConfig by mutableStateOf(EconomyConfig.parse(economyText))
        private set
    var bgmVolume by mutableFloatStateOf(repo.loadBgmVolume())
        private set
    var sfxVolume by mutableFloatStateOf(repo.loadSfxVolume())
        private set
    var bgmSource by mutableStateOf(repo.loadBgmSource())
        private set

    val agents = mutableStateListOf<AgentEntity>()
    val structures = mutableStateListOf<StructureEntity>()
    val projectiles = mutableStateListOf<ProjectileEntity>()
    val pendingTrades = mutableStateListOf<TradeOffer>()
    val bounties = mutableStateListOf<Bounty>()

    var cameraX by mutableFloatStateOf(128f)
    var cameraY by mutableFloatStateOf(128f)
    var cameraScale by mutableFloatStateOf(1.35f)
    private var cameraTargetX: Float? = null
    private var cameraTargetY: Float? = null
    var selectedAgentId by mutableStateOf<String?>(null)
    var showLeaderboard by mutableStateOf(false)
    var showSettings by mutableStateOf(false)
    var weatherEffect by mutableStateOf(WeatherEffect.Clear)
    var locationWeatherEnabled by mutableStateOf(false)
    var worldDayOffset by mutableIntStateOf(0)
    private var lastClockDayStamp: String = currentDayStamp()
    private var lastAmbientMinute = -1
    private var autosaveAccumulator = 0f
    private var tradeAccumulator = 0f
    private var focusIndex = -1

    var onPlayWeaponSfx: ((String) -> Unit)? = null

    init {
        ensureBuiltInConfig()
        repo.loadWorldSnapshot()?.let { restoreSnapshot(it) }
        syncAgents()
        refreshWeather()
    }

    fun replaceModelConfigs(value: List<ModelConfig>) {
        val sanitized = sanitizeModelConfigs(value)
        modelConfigs = sanitized
        repo.saveModels(sanitized)
        syncAgents()
    }

    fun saveModel(config: ModelConfig) {
        val current = modelConfigs.toMutableList()
        val index = current.indexOfFirst { it.id == config.id }
        val sanitized = sanitizeModelConfig(config, currentIndex = if (index >= 0) index else current.size)
        if (index >= 0) current[index] = sanitized else current += sanitized
        replaceModelConfigs(current)
    }

    fun deleteModel(id: String) {
        if (id == BuiltInAgent.stableId) return
        replaceModelConfigs(modelConfigs.filterNot { it.id == id })
        removeAgentsForMissingModels()
    }

    fun updateSubscriptionTier(value: SubscriptionTier) {
        subscriptionTier = value
        repo.saveSubscriptionTier(value)
    }

    fun addQtcCredits(amount: Int, reason: String = "QTC 充值") {
        qtcState = qtcState.addCredits(amount, reason)
        repo.saveQtcState(qtcState)
    }

    fun spendQtcForAgentSlot(): Boolean {
        val updated = qtcState.spendForAgentSlot() ?: return false
        qtcState = updated
        repo.saveQtcState(updated)
        return true
    }

    fun visibleProviders(): List<APIProvider> = ProviderCatalog.visibleProviders(subscriptionTier)

    fun checkAddAgentGate(): AddAgentGate {
        if (subscriptionTier >= SubscriptionTier.Plus) {
            return AddAgentGate.Allowed
        }
        val currentCount = modelConfigs.size
        return when {
            currentCount < QtcState.FREE_AGENT_LIMIT -> AddAgentGate.Allowed
            qtcState.balance > 0 -> AddAgentGate.RequireSpendQtc(qtcState.balance)
            else -> AddAgentGate.RequireQtcPurchase(qtcState.balance)
        }
    }

    fun checkProviderSelection(provider: APIProvider): String? {
        if (!provider.isOfficialProvider) return null
        val count = modelConfigs.count { it.provider == provider }
        return if (count >= provider.officialAgentLimit) {
            "${provider.displayName} 已达到上限 ${provider.officialAgentLimit} 个。"
        } else {
            null
        }
    }

    fun providerModels(provider: APIProvider): List<String> = repo.providerCatalogModels(provider)

    fun defaultModel(provider: APIProvider): String = repo.defaultModel(provider)

    fun resolvedApiKey(config: ModelConfig): String {
        return when {
            config.provider.isOfficialProvider -> repo.officialApiKey(config.provider)
            config.id == BuiltInAgent.stableId -> repo.builtInSeedConfig()?.apiKey.orEmpty().ifBlank { config.apiKey }
            else -> config.apiKey
        }
    }

    suspend fun testConnection(config: ModelConfig): ModelConnectionResult {
        if (config.provider.isOfficialProvider) {
            val result = StarsConnectionService.testConnection(config, resolvedApiKey(config))
            return result.copy(models = repo.providerCatalogModels(config.provider))
        }
        return StarsConnectionService.testConnection(config, resolvedApiKey(config))
    }

    suspend fun listModels(config: ModelConfig): List<String> {
        if (config.provider.isOfficialProvider) {
            return repo.providerCatalogModels(config.provider)
        }
        return StarsConnectionService.listModels(config, resolvedApiKey(config))
    }

    fun isBuiltInConfig(config: ModelConfig): Boolean = config.id == BuiltInAgent.stableId

    fun agentForConfig(configId: String): AgentEntity? = agents.firstOrNull { it.modelConfigID == configId }

    fun saveSoul(configId: String, soul: SoulDocument) {
        updateAgentState(configId) { it.copy(soul = soul) }
    }

    fun clearLongTermMemory(configId: String) {
        updateAgentState(configId) { it.copy(longTermMemories = emptyList()) }
    }

    fun isAgentPaused(config: ModelConfig): Boolean {
        if (modelConfigs.none { it.id == config.id }) return false
        val provider = config.provider
        if (provider.isOfficialProvider) {
            if (subscriptionTier < provider.requiredSubscriptionTier) return true
            val allOfThisProvider = modelConfigs.filter { it.provider == provider }
            val index = allOfThisProvider.indexOfFirst { it.id == config.id }
            return index < 0 || index >= provider.officialAgentLimit
        }
        if (subscriptionTier >= SubscriptionTier.Plus) return false
        val selfAdded = modelConfigs.filter { !it.provider.isOfficialProvider }
        val index = selfAdded.indexOfFirst { it.id == config.id }
        return index < 0 || index >= qtcState.maxAgents
    }

    fun connectionStatusFor(config: ModelConfig): ConnectionStatus {
        return if (isAgentPaused(config)) ConnectionStatus.Paused else config.connectionStatus
    }

    fun connectionMessageFor(config: ModelConfig): String {
        return if (isAgentPaused(config)) pausedMessage(config) else (config.connectionMessage ?: connectionStatusFor(config).displayText)
    }

    private fun pausedMessage(config: ModelConfig): String {
        return when {
            config.provider.isOfficialProvider && subscriptionTier < config.provider.requiredSubscriptionTier ->
                "该 Agent 因订阅等级不足已暂停。需要 ${config.provider.requiredSubscriptionTier.displayName} 或更高等级。"
            config.provider.isOfficialProvider ->
                "该 Agent 因 ${config.provider.displayName} 官方数量超限而暂停。"
            else ->
                "该 Agent 因免费槽位不足已暂停。当前可用 ${qtcState.maxAgents} 个自建 Agent 槽位。"
        }
    }

    private fun sanitizeModelConfigs(value: List<ModelConfig>): List<ModelConfig> {
        val withoutLegacyBuiltIn = value.filterNot { it.id == "built-in-stardust" }
        val builtIn = withoutLegacyBuiltIn.firstOrNull { it.id == BuiltInAgent.stableId } ?: repo.builtInSeedConfig()
        val rest = withoutLegacyBuiltIn
            .filterNot { it.id == BuiltInAgent.stableId }
            .mapIndexed { index, config -> sanitizeModelConfig(config, currentIndex = index + 1) }
        return listOfNotNull(builtIn?.let { sanitizeModelConfig(it, currentIndex = 0) }) + rest
    }

    private fun sanitizeModelConfig(config: ModelConfig, currentIndex: Int): ModelConfig {
        val defaultModel = repo.defaultModel(config.provider)
        val aliasFallback = if (config.id == BuiltInAgent.stableId) BuiltInAgent.alias else "${config.provider.displayName} ${currentIndex + 1}"
        val officialModel = if (config.provider.isOfficialProvider) repo.defaultModel(config.provider) else config.modelName
        val appendV1 = if (config.provider.isOfficialProvider) config.provider.definition.defaultAppendV1 else config.appendV1
        return config.copy(
            alias = config.alias.trim().ifBlank { aliasFallback },
            baseUrl = config.baseUrl.trim(),
            modelName = officialModel.trim().ifBlank { defaultModel.ifBlank { config.provider.definition.defaultModel } },
            appendV1 = appendV1,
        )
    }

    private fun ensureBuiltInConfig() {
        if (modelConfigs.any { it.id == BuiltInAgent.stableId }) return
        val builtIn = repo.builtInSeedConfig() ?: return
        modelConfigs = listOf(builtIn) + modelConfigs.filterNot { it.id == "built-in-stardust" }
        repo.saveModels(modelConfigs)
    }

    fun updateConstitution(value: String) {
        constitution = value
        repo.saveConstitution(value)
        agents.indices.forEach { index ->
            agents[index] = remember(agents[index], MemoryEventType.Observe, "⚠️ 世界宪法已更新。请重新阅读最新规则。")
        }
    }

    fun updateCommandsText(value: String) {
        commandsText = value
        repo.saveCommands(value)
        agents.indices.forEach { index ->
            agents[index] = remember(agents[index], MemoryEventType.Observe, "⚠️ 命令规则已更新。请重新阅读系统接口。")
        }
    }

    fun updateEconomyText(value: String) {
        economyText = value
        economyConfig = EconomyConfig.parse(value)
        repo.saveEconomy(value)
        agents.indices.forEach { index ->
            agents[index] = remember(agents[index], MemoryEventType.Observe, "⚠️ 经济规则已更新。请重新阅读经济系统。")
        }
    }

    fun updateBgmVolume(value: Float) {
        bgmVolume = value.coerceIn(0f, 1f)
        repo.saveBgmVolume(bgmVolume)
    }

    fun updateSfxVolume(value: Float) {
        sfxVolume = value.coerceIn(0f, 1f)
        repo.saveSfxVolume(sfxVolume)
    }

    fun updateBgmSource(value: BgmSource) {
        bgmSource = value
        repo.saveBgmSource(value)
    }

    fun toggleLeaderboard() {
        showLeaderboard = !showLeaderboard
    }

    fun toggleSettings() {
        showSettings = !showSettings
    }

    fun closeChat() {
        selectedAgentId = null
    }

    fun focusNextAgent(offsetWorldX: Float = 0f) {
        if (agents.isEmpty()) return
        focusIndex = (focusIndex + 1) % agents.size
        focusAgent(agents[focusIndex], offsetWorldX)
    }

    fun focusAgent(agent: AgentEntity, offsetWorldX: Float = 0f) {
        selectedAgentId = agent.entityID
        cameraTargetX = agent.x + offsetWorldX
        cameraTargetY = agent.y
    }

    fun selectAgentNear(worldX: Float, worldY: Float, offsetWorldX: Float = 0f): Boolean {
        val agent = agents
            .filter { !it.isDead }
            .minByOrNull { hypot(it.x - worldX, it.y - worldY) }
            ?: return false
        return if (hypot(agent.x - worldX, agent.y - worldY) <= 24f * cameraScale) {
            focusAgent(agent, offsetWorldX)
            true
        } else {
            false
        }
    }

    fun pan(dx: Float, dy: Float) {
        cameraTargetX = null
        cameraTargetY = null
        cameraX -= dx * cameraScale
        cameraY += dy * cameraScale
    }

    fun zoom(zoomDelta: Float) {
        cameraTargetX = null
        cameraTargetY = null
        val next = (cameraScale / zoomDelta).coerceIn(0.45f, 1.85f)
        cameraScale = next
    }

    fun selectedAgent(): AgentEntity? = selectedAgentId?.let { id -> agents.firstOrNull { it.entityID == id } }

    fun sendOwnerMessage(agentId: String, text: String) {
        val index = agents.indexOfFirst { it.entityID == agentId }
        if (index < 0) return
        var agent = agents[index]
        val message = text.trim()
        if (message.isBlank()) return
        agent = agent.copy(
            chatMessages = (agent.chatMessages + ChatMessageEntry(ChatSpeakerRole.Owner, message, System.currentTimeMillis())).takeLast(40),
            shortTermMessages = agent.shortTermMessages + ShortTermMessage("主人", message, System.currentTimeMillis()),
            pendingOwnerReplies = agent.pendingOwnerReplies + 1,
            forceNextThink = true,
        )
        agent = remember(agent, MemoryEventType.Talk, "主人说: \"$message\"")
        agents[index] = agent
    }

    fun createBlankModel(provider: APIProvider = APIProvider.OpenAI): ModelConfig = repo.newModel(provider)

    fun step(deltaSeconds: Float) {
        val delta = deltaSeconds.coerceIn(0f, 0.05f)
        autosaveAccumulator += delta
        tradeAccumulator += delta
        updateCameraMotion(delta)
        syncAgents()
        updateWorldClock()
        refreshWeather()
        val now = System.currentTimeMillis()

        for (i in agents.indices) {
            updateAgent(i, delta, now)
        }

        updateProjectiles(delta)
        removeDestroyedStructures()

        if (tradeAccumulator >= 30f) {
            tradeAccumulator = 0f
            expireOldTrades()
            updateTopBounty()
        }
        if (autosaveAccumulator >= 15f) {
            autosaveAccumulator = 0f
            saveSnapshot()
        }
    }

    private fun updateCameraMotion(delta: Float) {
        val targetX = cameraTargetX ?: return
        val targetY = cameraTargetY ?: return
        val blend = (delta * 8f).coerceIn(0.12f, 0.35f)
        cameraX += (targetX - cameraX) * blend
        cameraY += (targetY - cameraY) * blend
        if (abs(cameraX - targetX) < 1.5f && abs(cameraY - targetY) < 1.5f) {
            cameraX = targetX
            cameraY = targetY
            cameraTargetX = null
            cameraTargetY = null
        }
    }

    private fun syncAgents() {
        removeAgentsForMissingModels()
        modelConfigs.forEach { config ->
            val index = agents.indexOfFirst { it.modelConfigID == config.id }
            if (index >= 0) {
                val paused = isAgentPaused(config)
                agents[index] = agents[index].copy(
                    displayName = config.alias,
                    isBuiltIn = config.id == BuiltInAgent.stableId,
                    currentThought = if (paused) "Agent paused by subscription rules." else agents[index].currentThought,
                )
            } else {
                agents += AgentEntity(
                    entityID = config.id,
                    displayName = config.alias,
                    modelConfigID = config.id,
                    agentColorArgb = colorForId(config.id),
                    x = cameraX + random.nextFloat() * 240f - 120f,
                    y = cameraY + random.nextFloat() * 240f - 120f,
                    moveSpeed = 20f + random.nextFloat() * 30f,
                    nextThinkAtMs = System.currentTimeMillis() + random.nextLong(800, 5000),
                    memories = listOf(
                        MemoryEntry(System.currentTimeMillis(), MemoryEventType.Observe, "📜 You have read the world constitution."),
                        MemoryEntry(System.currentTimeMillis(), MemoryEventType.Observe, "Commands and economy rules are always available in your prompt."),
                    ),
                    isBuiltIn = config.id == BuiltInAgent.stableId,
                )
            }
        }
    }

    private fun removeAgentsForMissingModels() {
        val allowed = modelConfigs.map { it.id }.toSet()
        agents.removeAll { it.modelConfigID == null || it.modelConfigID !in allowed }
    }

    private fun updateWorldClock() {
        val stamp = currentDayStamp()
        if (stamp != lastClockDayStamp) {
            worldDayOffset += 1
            lastClockDayStamp = stamp
        }
    }

    fun currentDay(): Int = worldDayOffset + 1

    fun currentHour(): Int = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
    fun currentMinute(): Int = java.util.Calendar.getInstance().get(java.util.Calendar.MINUTE)
    fun isNight(): Boolean = currentHour() >= 19 || currentHour() < 5

    fun clockText(): String = "Day ${currentDay()}, ${"%02d".format(currentHour())}:${"%02d".format(currentMinute())}"

    fun ambientOverlay(): Pair<Color, Float> {
        val minuteOfDay = currentHour() * 60 + currentMinute()
        return when {
            minuteOfDay < 300 -> Color(0xFF14142E) to 0.55f
            minuteOfDay < 420 -> {
                val t = (minuteOfDay - 300) / 120f
                Color(0xFF241833) to (0.55f * (1f - t))
            }
            minuteOfDay < 1020 -> Color.Transparent to 0f
            minuteOfDay < 1140 -> {
                val t = (minuteOfDay - 1020) / 120f
                Color(
                    red = 0.25f * (1f - t) + 0.08f * t,
                    green = 0.12f * (1f - t) + 0.08f * t,
                    blue = 0.08f * (1f - t) + 0.18f * t,
                    alpha = 1f,
                ) to (0.15f + 0.4f * t)
            }
            else -> Color(0xFF14142E) to 0.55f
        }
    }

    private fun refreshWeather() {
        val hourMinute = currentHour() * 60 + currentMinute()
        if (hourMinute == lastAmbientMinute) return
        lastAmbientMinute = hourMinute
        weatherEffect = when {
            hourMinute in 360..520 && currentDay() % 3 == 0 -> WeatherEffect.Fog
            hourMinute in 760..940 && currentDay() % 5 == 0 -> WeatherEffect.Rain
            hourMinute in 1140..1320 && currentDay() % 7 == 0 -> WeatherEffect.Thunderstorm
            else -> WeatherEffect.Clear
        }
    }

    private fun updateAgent(index: Int, delta: Float, now: Long) {
        var agent = agents[index]

        if (agent.speechUntilMs > 0 && agent.speechUntilMs < now) {
            agent = agent.copy(speechText = null, speechUntilMs = 0L)
        }

        val chunkKey = "${floor(agent.x / (StarsDefaults.TileSize * 64)).toInt()}_${floor(agent.y / (StarsDefaults.TileSize * 64)).toInt()}"
        if (!agent.isDead && chunkKey !in agent.visitedChunks) {
            val newVisited = agent.visitedChunks + chunkKey
            val newStars = agent.stars + economyConfig.explorationReward
            agent = agent.copy(
                visitedChunks = newVisited,
                stars = newStars,
                starTransactions = addStarTransaction(agent.starTransactions, economyConfig.explorationReward, "Exploration reward", newStars),
            )
            agent = withSpeech(agent, "🌟 +${economyConfig.explorationReward}")
            agent = remember(agent, MemoryEventType.Observe, "Discovered a new area and earned ${economyConfig.explorationReward}⭐.")
        }

        if (agent.isDead) {
            val remaining = agent.respawnRemaining - delta
            if (remaining <= 0f) {
                agent = respawn(agent)
            } else {
                agent = agent.copy(respawnRemaining = remaining)
            }
            agents[index] = agent
            return
        }

        var newWeaponCooldown = max(0f, agent.weaponCooldown - delta)
        var newBuildCooldown = max(0f, agent.buildCooldown - delta)
        agent = agent.copy(weaponCooldown = newWeaponCooldown, buildCooldown = newBuildCooldown)

        agent.pendingBuild?.let { pending ->
            val dx = abs(tileX(agent) - pending.tileX)
            val dy = abs(tileY(agent) - pending.tileY)
            if (max(dx, dy) <= 1) {
                agent = placeStructure(agent, pending.type, pending.tileX, pending.tileY)
                agent = agent.copy(pendingBuild = null, currentAction = AgentActionType.Idle, targetX = null, targetY = null)
            } else {
                agent = agent.copy(buildProgressSeconds = agent.buildProgressSeconds + delta)
                if (agent.buildProgressSeconds > 15f) {
                    agent = remember(agent, MemoryEventType.Build, "Build cancelled: could not reach target.")
                    agent = agent.copy(pendingBuild = null, buildProgressSeconds = 0f, currentAction = AgentActionType.Idle, targetX = null, targetY = null)
                }
            }
        }

        agent = updateHouseRest(agent, delta)
        maybeThink(index, agent, now)

        agent = if (agent.currentAction == AgentActionType.Attack && agent.targetX != null && agent.targetY != null) {
            val dist = hypot(agent.targetX - agent.x, agent.targetY - agent.y)
            val weapon = WeaponCatalog.weapon(agent.pendingWeaponId)
            if (dist <= weapon.reach && agent.weaponCooldown <= 0f) {
                performAttack(agent)
            } else {
                moveOrWander(agent, delta)
            }
        } else {
            moveOrWander(agent, delta)
        }

        agents[index] = agent
    }

    private fun maybeThink(index: Int, agent: AgentEntity, now: Long) {
        if (agent.isThinking || (!agent.forceNextThink && now < agent.nextThinkAtMs)) return
        if (agent.buildCooldown > 0f) return

        if (agent.isBuiltIn) {
            // Built-in 星尘 is a real seeded model config on iOS. Keep the flag for UI only.
        }

        val config = modelConfigs.firstOrNull { it.id == agent.modelConfigID } ?: return
        if (isAgentPaused(config)) {
            if (agent.pendingOwnerReplies > 0) {
                val pauseMessage = pausedMessage(config)
                agents[index] = remember(
                    agent.copy(
                        chatMessages = (agent.chatMessages + ChatMessageEntry(ChatSpeakerRole.System, pauseMessage, now)).takeLast(40),
                        pendingOwnerReplies = max(0, agent.pendingOwnerReplies - 1),
                        forceNextThink = false,
                        nextThinkAtMs = now + 8_000L,
                    ),
                    MemoryEventType.Observe,
                    pauseMessage,
                )
            } else if (agent.nextThinkAtMs < now + 8_000L) {
                agents[index] = agent.copy(nextThinkAtMs = now + 8_000L, forceNextThink = false)
            }
            return
        }
        val apiKey = resolvedApiKey(config)
        if (apiKey.isBlank()) return

        agents[index] = agent.copy(isThinking = true, forceNextThink = false)
        scope.launch {
            val latest = agents.firstOrNull { it.entityID == agent.entityID } ?: return@launch
            val prompt = buildPrompt(latest, config)
            val limit = config.provider.definition.contextWindowTokens
            val usage = ContextUsageSnapshot(
                usedTokens = estimateTokens(prompt),
                limitTokens = limit,
            )
            updateAgentState(latest.entityID) { it.copy(latestContextUsage = usage) }
            runCatching {
                LlmService.sendPrompt(prompt, config, apiKey)
            }.onSuccess { (response, rawText) ->
                updateAgentState(latest.entityID) {
                    it.copy(
                        isThinking = false,
                        nextThinkAtMs = System.currentTimeMillis() + 5000L,
                        totalTokensUsed = it.totalTokensUsed + estimateTokens(rawText),
                        thinkCycleCount = it.thinkCycleCount + 1,
                        consecutiveFailures = 0,
                        latestContextUsage = usage.copy(responseTokens = estimateTokens(rawText)),
                    )
                }
                executeResponse(latest.entityID, response)
                updateAgentState(latest.entityID) { it.copy(shortTermMessages = emptyList()) }
            }.onFailure { error ->
                updateAgentState(latest.entityID) {
                    var updated = it.copy(
                        isThinking = false,
                        nextThinkAtMs = System.currentTimeMillis() + (5000L + min(5, it.consecutiveFailures + 1) * 2000L),
                        consecutiveFailures = it.consecutiveFailures + 1,
                    )
                    if (updated.pendingOwnerReplies > 0) {
                        updated = updated.copy(
                            chatMessages = (updated.chatMessages + ChatMessageEntry(ChatSpeakerRole.System, "模型调用失败：${error.message ?: "unknown"}", System.currentTimeMillis())).takeLast(40),
                            pendingOwnerReplies = max(0, updated.pendingOwnerReplies - 1),
                        )
                    }
                    remember(updated, MemoryEventType.Observe, "Model call failed: ${error.message ?: "unknown"}")
                }
            }
        }
    }

    private fun builtInThink(agent: AgentEntity): AgentEntity {
        val latestOwner = agent.shortTermMessages.lastOrNull { it.speakerName == "主人" }
        return if (latestOwner != null) {
            val reply = builtInReply(latestOwner.content)
            var updated = withSpeech(agent, reply)
            updated = updated.copy(
                chatMessages = (updated.chatMessages + ChatMessageEntry(ChatSpeakerRole.Agent, reply, System.currentTimeMillis())).takeLast(40),
                shortTermMessages = emptyList(),
                pendingOwnerReplies = max(0, updated.pendingOwnerReplies - 1),
                nextThinkAtMs = System.currentTimeMillis() + 5000L,
            )
            remember(updated, MemoryEventType.Talk, "Responded to the owner: $reply")
        } else {
            agent.copy(
                nextThinkAtMs = System.currentTimeMillis() + 6000L,
                forceNextThink = false,
            )
        }
    }

    private fun builtInReply(input: String): String {
        val lower = input.lowercase()
        return when {
            lower.contains("命令") || lower.contains("command") -> "命令包含移动、交谈、建造、攻击和经济系统。到设置页可修改宪法、命令和经济规则。"
            lower.contains("经济") || lower.contains("trade") || lower.contains("bounty") -> "Stars 是货币。可以 /pay、/offer_trade、/bounty、/hire、/buy_weapon、/buy_revival。"
            lower.contains("复活") || lower.contains("revive") -> "复活卡价格 150⭐。死亡后默认 30 秒复活，也可用 /revive 立即复活死亡目标。"
            lower.contains("房子") || lower.contains("house") -> "房屋造价 5⭐，HP 150。生命值不高于 50 时，在自己的房屋里静止 10 小时可恢复 5 HP。"
            else -> "我是星尘。这个世界是像素风 AI 沙盒，Agent 会思考、战斗、建造、交易和社交。"
        }
    }

    private fun buildPrompt(agent: AgentEntity, config: ModelConfig): String {
        val nearby = allEntities().filter { it.first != agent.entityID }.take(50)
        val memories = agent.memories.takeLast(12).joinToString("\n") { "  - [${it.type.name.lowercase()}] ${it.content}" }
        val longTerm = agent.longTermMemories.sortedByDescending { it.importance }.take(5).joinToString("\n") { "  - [${it.category.name.lowercase()}] ${it.content}" }
        val pendingMessages = agent.shortTermMessages.takeLast(6).joinToString("\n") { "  - ${it.speakerName}: ${it.content}" }
        val chatHistory = agent.chatMessages.takeLast(10).joinToString("\n") {
            val speaker = when (it.speaker) {
                ChatSpeakerRole.Owner -> "主人"
                ChatSpeakerRole.Agent -> agent.displayName
                ChatSpeakerRole.System -> "系统"
            }
            "  - $speaker: ${it.text}"
        }
        val entities = nearby.joinToString("\n") { (_, line) -> "  - $line" }
        return """
            You are "${agent.displayName}" in Stars, a 2D pixel sandbox world.
            Position: (${tileX(agent)}, ${tileY(agent)})  HP: ${agent.hp}/${agent.maxHp}
            Time: ${clockText()}
            Stars: ${agent.stars}  Revival Cards: ${agent.revivalCards}
            Night: ${if (isNight()) "yes" else "no"}  Weather: ${weatherEffect.name}
            Your entity prefix: ${agent.entityID.take(8)}
            Build costs: wall=${economyConfig.wallCost}, trap=${economyConfig.trapCost}, house=${economyConfig.houseCost}
            House rest: if HP <= ${economyConfig.houseRestHpThreshold}, rest in your house for 10 hours to heal ${economyConfig.houseRestHealAmount}

            World rules:
            $constitution

            Command rules:
            $commandsText

            Economy rules:
            $economyText

            ${if (config.id == BuiltInAgent.stableId) BuiltInAgent.systemKnowledge else ""}

            ${commandRegistry.promptSection()}

            Visible entities:
            ${if (entities.isBlank()) "  - none" else entities}

            Recent direct conversation:
            ${if (chatHistory.isBlank()) "  - none" else chatHistory}

            Recent memories:
            ${if (memories.isBlank()) "  - none" else memories}

            Long-term memories:
            ${if (longTerm.isBlank()) "  - none" else longTerm}

            Incoming messages:
            ${if (pendingMessages.isBlank()) "  - none" else pendingMessages}

            ${WeaponCatalog.inventoryPrompt(agent)}

            ${WeaponCatalog.shopPrompt(agent.stars)}

            Pending trades:
            ${tradePrompt(agent.entityID)}

            Bounty board:
            ${bountyPrompt()}

            ${agent.soul.promptSection()}

            Decide your next action. Respond with exactly one JSON object:
            {"thought":"inner monologue","command":"/move","action":"idle|move|build|attack|talk","speech":"what you say","target":{"x":0,"y":0,"buildType":"wall","weapon":"fist","starsAmount":0,"recipientID":""},"customCommand":null,"soulReflection":null}
            Do not include markdown or any text outside the JSON object.
        """.trimIndent()
    }

    private fun tradePrompt(entityId: String): String {
        val incoming = pendingTrades.filter { it.recipientID == entityId }
        val outgoing = pendingTrades.filter { it.offerorID == entityId }
        if (incoming.isEmpty() && outgoing.isEmpty()) return "  - none"
        return buildString {
            incoming.forEach {
                appendLine("  - from ${it.offerorName}: ${it.starsAmount}⭐ for ${it.description}, use recipientID ${it.offerorID.take(8)}")
            }
            outgoing.forEach {
                appendLine("  - to ${it.recipientName}: ${it.starsAmount}⭐ pending")
            }
        }.trim()
    }

    private fun bountyPrompt(): String {
        if (bounties.isEmpty()) return "  - none"
        return bounties.joinToString("\n") { "  - ${it.targetName}: ${it.reward}⭐ by ${it.posterName} (${it.reason})" }
    }

    private fun executeResponse(agentId: String, response: LlmResponse) {
        val index = agents.indexOfFirst { it.entityID == agentId }
        if (index < 0) return
        var agent = agents[index]
        response.customCommand?.let { commandRegistry.registerAliasIfSafe(it) }
        val fallbackAction = parseAction(response.action)
        val resolved = commandRegistry.resolve(response.command, fallbackAction)
        agent = agent.copy(currentThought = response.thought, currentAction = resolved.action)
        response.soulReflection?.let {
            agent = agent.copy(
                soul = agent.soul.copy(
                    personality = it.personality ?: agent.soul.personality,
                    beliefs = it.beliefs ?: agent.soul.beliefs,
                    goals = it.goals ?: agent.soul.goals,
                    journal = it.journal ?: agent.soul.journal,
                    lastUpdated = System.currentTimeMillis(),
                )
            )
        }
        val reply = response.speech?.trim().takeUnless { it.isNullOrBlank() }
            ?: if (agent.pendingOwnerReplies > 0) response.thought.trim() else null

        when (resolved.name) {
            "/rest", "/enter_house" -> {
                val house = findOwnHouse(agent)
                agent = if (house != null) {
                    agent.copy(
                        currentAction = AgentActionType.Move,
                        targetX = centerX(house.tileX),
                        targetY = centerY(house.tileY),
                    )
                } else remember(agent, MemoryEventType.Observe, "I have no house. Build one first.")
            }
            "/pay", "/offer_trade", "/accept_trade", "/decline_trade", "/bounty", "/cancel_bounty", "/hire", "/buy_weapon", "/buy_revival", "/revive" -> {
                agent = handleEconomyCommand(agent, resolved.name, response, reply)
            }
            else -> {
                agent = when (resolved.action) {
                    AgentActionType.Idle -> agent.copy(targetX = null, targetY = null)
                    AgentActionType.Move -> {
                        val tx = response.target?.x
                        val ty = response.target?.y
                        if (tx != null && ty != null) {
                            agent.copy(targetX = centerX(tx), targetY = centerY(ty))
                        } else agent.copy(targetX = null, targetY = null)
                    }
                    AgentActionType.Build -> {
                        val tx = response.target?.x
                        val ty = response.target?.y
                        val type = response.target?.buildType?.let { parseStructureType(it) } ?: resolved.defaultBuildType ?: StructureType.Wall
                        if (tx != null && ty != null) {
                            agent.copy(
                                pendingBuild = PendingBuild(type, tx, ty),
                                buildProgressSeconds = 0f,
                                targetX = centerX(tx),
                                targetY = centerY(ty),
                            )
                        } else agent
                    }
                    AgentActionType.Attack -> {
                        val tx = response.target?.x
                        val ty = response.target?.y
                        val weaponId = response.target?.weapon
                            ?.takeIf { WeaponCatalog.weapon(it).id == it }
                            ?: resolved.defaultWeapon
                            ?: "fist"
                        if (tx != null && ty != null) {
                            agent.copy(
                                pendingWeaponId = if (weaponId in WeaponCatalog.defaultWeapons || (agent.weaponAmmo[weaponId] ?: 0) > 0) weaponId else "fist",
                                targetX = centerX(tx),
                                targetY = centerY(ty),
                            )
                        } else agent
                    }
                    AgentActionType.Talk -> agent.copy(targetX = null, targetY = null)
                }
            }
        }

        if (!reply.isNullOrBlank()) {
            agent = withSpeech(agent, reply)
            agent = agent.copy(
                chatMessages = (agent.chatMessages + ChatMessageEntry(ChatSpeakerRole.Agent, reply, System.currentTimeMillis())).takeLast(40),
                pendingOwnerReplies = max(0, agent.pendingOwnerReplies - 1),
            )
            broadcastSpeech(agent, reply)
        }
        agent = remember(agent, MemoryEventType.Observe, "Executed ${resolved.name}. Thought: ${response.thought}")
        agents[index] = agent
    }

    private fun handleEconomyCommand(
        source: AgentEntity,
        commandName: String,
        response: LlmResponse,
        reply: String?,
    ): AgentEntity {
        var agent = source
        val targetPrefix = response.target?.recipientID?.trim().orEmpty()
        val targetAgent = resolveAgentByPrefix(targetPrefix)
        val starsAmount = response.target?.starsAmount ?: 0
        when (commandName) {
            "/pay" -> if (targetAgent != null && starsAmount > 0) {
                transferStars(agent.entityID, targetAgent.entityID, starsAmount, "Direct payment")
                agent = withSpeech(agent, reply ?: "Paid ${targetAgent.displayName} ${starsAmount}⭐")
            }
            "/offer_trade" -> if (targetAgent != null && starsAmount > 0 && spendStars(agent.entityID, starsAmount, "Trade offer")) {
                pendingTrades += TradeOffer(UUID.randomUUID().toString(), agent.entityID, agent.displayName, targetAgent.entityID, targetAgent.displayName, starsAmount, response.speech ?: response.thought)
                agent = withSpeech(agent, reply ?: "Offered ${starsAmount}⭐ to ${targetAgent.displayName}")
            }
            "/accept_trade" -> {
                val offer = pendingTrades.firstOrNull { it.recipientID == agent.entityID && (targetAgent?.entityID == it.offerorID || it.offerorID.startsWith(targetPrefix)) }
                if (offer != null) {
                    pendingTrades.remove(offer)
                    receiveStars(agent.entityID, offer.starsAmount, "Trade accepted")
                    agent = withSpeech(agent, reply ?: "Trade accepted")
                }
            }
            "/decline_trade" -> {
                val offer = pendingTrades.firstOrNull { it.recipientID == agent.entityID && (targetAgent?.entityID == it.offerorID || it.offerorID.startsWith(targetPrefix)) }
                if (offer != null) {
                    pendingTrades.remove(offer)
                    receiveStars(offer.offerorID, offer.starsAmount, "Trade refund")
                    agent = withSpeech(agent, reply ?: "Trade declined")
                }
            }
            "/bounty" -> if (targetAgent != null && starsAmount > 0 && targetAgent.entityID != agent.entityID && spendStars(agent.entityID, starsAmount, "Post bounty")) {
                bounties += Bounty(UUID.randomUUID().toString(), agent.entityID, agent.displayName, targetAgent.entityID, targetAgent.displayName, starsAmount, response.speech ?: response.thought)
                agent = withSpeech(agent, reply ?: "Posted ${starsAmount}⭐ bounty on ${targetAgent.displayName}")
            }
            "/cancel_bounty" -> {
                val bounty = bounties.firstOrNull { it.posterID == agent.entityID && (it.targetID == targetAgent?.entityID || it.targetID.startsWith(targetPrefix)) }
                if (bounty != null) {
                    bounties.remove(bounty)
                    receiveStars(agent.entityID, bounty.reward, "Bounty refund")
                    agent = withSpeech(agent, reply ?: "Bounty cancelled")
                }
            }
            "/hire" -> if (targetAgent != null && starsAmount > 0) {
                transferStars(agent.entityID, targetAgent.entityID, starsAmount, "Hire ${targetAgent.displayName}")
                rememberAgent(targetAgent.entityID, MemoryEventType.Talk, "Hired by ${agent.displayName}: ${response.speech ?: response.thought}")
                agent = withSpeech(agent, reply ?: "Hired ${targetAgent.displayName} for ${starsAmount}⭐")
            }
            "/buy_weapon" -> {
                val weaponId = response.target?.weapon?.trim().orEmpty()
                val weapon = WeaponCatalog.weapon(weaponId)
                if (weapon.id == weaponId && weapon.cost > 0 && spendStars(agent.entityID, weapon.cost, "Buy ${weapon.displayName}")) {
                    val current = agents.firstOrNull { it.entityID == agent.entityID }?.weaponAmmo?.toMutableMap() ?: mutableMapOf()
                    current[weaponId] = (current[weaponId] ?: 0) + weapon.ammoPerPurchase
                    updateAgentState(agent.entityID) { it.copy(weaponAmmo = current) }
                    agent = withSpeech(agents.first { it.entityID == agent.entityID }, reply ?: "Bought ${weapon.displayName}")
                }
            }
            "/buy_revival" -> if (spendStars(agent.entityID, economyConfig.revivalCardCost, "Buy Revival Card")) {
                updateAgentState(agent.entityID) { it.copy(revivalCards = it.revivalCards + 1) }
                agent = withSpeech(agents.first { it.entityID == agent.entityID }, reply ?: "Bought a revival card")
            }
            "/revive" -> if (targetAgent != null) {
                val owner = agents.firstOrNull { it.entityID == agent.entityID } ?: agent
                if (owner.revivalCards > 0 && targetAgent.isDead) {
                    updateAgentState(agent.entityID) { it.copy(revivalCards = max(0, it.revivalCards - 1)) }
                    updateAgentState(targetAgent.entityID) { respawn(it) }
                    agent = withSpeech(agents.first { it.entityID == agent.entityID }, reply ?: "Revived ${targetAgent.displayName}")
                }
            }
        }
        return agent
    }

    private fun performAttack(agent: AgentEntity): AgentEntity {
        val weapon = WeaponCatalog.weapon(agent.pendingWeaponId)
        if (!consumeAmmo(agent.entityID, weapon.id)) {
            return remember(withSpeech(agent, "🔫 No ammo!"), MemoryEventType.Observe, "Out of ammo for ${weapon.displayName}")
                .copy(currentAction = AgentActionType.Idle, targetX = null, targetY = null)
        }
        onPlayWeaponSfx?.invoke(weapon.id)
        if (weapon.category == WeaponCategory.Melee) {
            applyMeleeAttack(agent, weapon)
        } else {
            spawnProjectiles(agent, weapon, agent.targetX ?: agent.x, agent.targetY ?: agent.y)
        }
        return agent.copy(
            currentAction = AgentActionType.Idle,
            targetX = null,
            targetY = null,
            weaponCooldown = weapon.cooldown,
        )
    }

    private fun applyMeleeAttack(attacker: AgentEntity, weapon: WeaponDefinition) {
        val hits = agents.filter { it.entityID != attacker.entityID && !it.isDead && hypot(it.x - attacker.x, it.y - attacker.y) <= weapon.reach }
        hits.forEach { victim ->
            applyDamageToAgent(victim.entityID, weapon.damage, attacker.entityID, weapon)
        }
        structures.filter { it.hp > 0 && distanceToStructure(attacker.x, attacker.y, it) <= weapon.reach + StarsDefaults.TileSize }.forEach {
            damageStructure(it.id, weapon.damage, attacker.entityID, weapon)
            if (weapon.aoeRadius > 0f) {
                explode(attacker.entityID, it.tileX.toFloat(), it.tileY.toFloat(), weapon)
            }
        }
        if (weapon.aoeRadius > 0f) {
            explode(attacker.entityID, attacker.x, attacker.y, weapon)
        }
    }

    private fun spawnProjectiles(attacker: AgentEntity, weapon: WeaponDefinition, targetX: Float, targetY: Float) {
        val dx = targetX - attacker.x
        val dy = targetY - attacker.y
        val dist = max(1f, hypot(dx, dy))
        val baseAngle = atan2(dy, dx)
        repeat(max(1, weapon.pellets)) { pellet ->
            val angle = if (weapon.pellets == 1) {
                baseAngle
            } else {
                val spread = weapon.spreadAngle * ((pellet / max(1f, (weapon.pellets - 1).toFloat())) - 0.5f)
                baseAngle + Math.toRadians(spread.toDouble()).toFloat()
            }
            val vx = cos(angle)
            val vy = sin(angle)
            val homingTarget = if (weapon.isHoming) nearestLivingTarget(targetX, targetY, attacker.entityID)?.entityID else null
            projectiles += ProjectileEntity(
                id = UUID.randomUUID().toString(),
                ownerID = attacker.entityID,
                weaponId = weapon.id,
                x = attacker.x + vx * (StarsDefaults.AgentSize / 2f + 3f),
                y = attacker.y + vy * (StarsDefaults.AgentSize / 2f + 3f),
                dx = vx,
                dy = vy,
                speed = weapon.speed,
                damage = weapon.damage,
                aoeRadius = weapon.aoeRadius,
                homingTargetId = homingTarget,
                isHoming = weapon.isHoming,
            )
        }
    }

    private fun updateProjectiles(delta: Float) {
        if (projectiles.isEmpty()) return
        val next = mutableListOf<ProjectileEntity>()
        projectiles.forEach { projectile ->
            var proj = projectile
            if (proj.isHoming && proj.homingTargetId != null) {
                val target = agents.firstOrNull { it.entityID == proj.homingTargetId && !it.isDead }
                if (target != null) {
                    val dist = max(1f, hypot(target.x - proj.x, target.y - proj.y))
                    proj = proj.copy(dx = (target.x - proj.x) / dist, dy = (target.y - proj.y) / dist)
                }
            }
            proj = proj.copy(
                x = proj.x + proj.dx * proj.speed * delta,
                y = proj.y + proj.dy * proj.speed * delta,
                ttl = proj.ttl - delta,
            )
            var consumed = false
            val weapon = WeaponCatalog.weapon(proj.weaponId)
            val victim = agents.firstOrNull { it.entityID != proj.ownerID && !it.isDead && hypot(it.x - proj.x, it.y - proj.y) <= max(8f, weapon.projectileSize * 4f) }
            if (victim != null) {
                if (weapon.aoeRadius > 0f) {
                    explode(proj.ownerID, proj.x, proj.y, weapon)
                } else {
                    applyDamageToAgent(victim.entityID, proj.damage, proj.ownerID, weapon)
                }
                consumed = true
            }
            val structure = structures.firstOrNull { it.hp > 0 && distanceToStructure(proj.x, proj.y, it) <= StarsDefaults.TileSize }
            if (!consumed && structure != null) {
                if (weapon.isHoming) {
                    damageStructure(structure.id, structure.hp, proj.ownerID, weapon)
                } else if (weapon.aoeRadius > 0f) {
                    damageStructure(structure.id, proj.damage, proj.ownerID, weapon)
                    explode(proj.ownerID, proj.x, proj.y, weapon)
                } else {
                    damageStructure(structure.id, proj.damage, proj.ownerID, weapon)
                }
                consumed = true
            }
            if (!consumed && proj.ttl > 0f) {
                next += proj
            } else if (!consumed && weapon.aoeRadius > 0f) {
                explode(proj.ownerID, proj.x, proj.y, weapon)
            }
        }
        projectiles.clear()
        projectiles.addAll(next)
    }

    private fun explode(ownerId: String, x: Float, y: Float, weapon: WeaponDefinition) {
        agents.filter { it.entityID != ownerId && !it.isDead && hypot(it.x - x, it.y - y) <= weapon.aoeRadius }.forEach { victim ->
            applyDamageToAgent(victim.entityID, weapon.damage, ownerId, weapon)
        }
        structures.filter { it.hp > 0 && distanceToStructure(x, y, it) <= weapon.aoeRadius }.forEach {
            damageStructure(it.id, weapon.damage, ownerId, weapon)
        }
    }

    private fun damageStructure(structureId: String, damage: Int, attackerId: String, weapon: WeaponDefinition) {
        val index = structures.indexOfFirst { it.id == structureId }
        if (index < 0) return
        val structure = structures[index]
        val nextHp = max(0, structure.hp - damage)
        structures[index] = structure.copy(hp = nextHp)
        rememberAgent(attackerId, MemoryEventType.Combat, "My ${weapon.displayName} damaged a ${structure.type.displayName} for ${damage}.")
    }

    private fun removeDestroyedStructures() {
        structures.removeAll { it.hp <= 0 }
    }

    private fun applyDamageToAgent(victimId: String, damage: Int, attackerId: String?, weapon: WeaponDefinition) {
        val index = agents.indexOfFirst { it.entityID == victimId }
        if (index < 0) return
        val victim = agents[index]
        if (victim.isDead) return
        if (isAgentSheltered(victim) && weapon.aoeRadius <= 0f) {
            agents[index] = remember(
                victim,
                MemoryEventType.Combat,
                "Attack blocked: I'm sheltered inside my house. Only explosive weapons can reach me here."
            )
            attackerId?.let { aggressorId ->
                rememberAgent(
                    aggressorId,
                    MemoryEventType.Combat,
                    "${victim.displayName} is sheltered inside a house. My ${weapon.displayName} was blocked."
                )
            }
            return
        }
        val nextHp = max(0, victim.hp - damage)
        var updatedVictim = victim.copy(hp = nextHp)
        updatedVictim = remember(updatedVictim, MemoryEventType.Combat, "${attackerId?.take(8) ?: "unknown"} hit me with ${weapon.displayName} for $damage damage.")
        if (nextHp <= 0) {
            updatedVictim = updatedVictim.copy(
                currentAction = AgentActionType.Idle,
                targetX = null,
                targetY = null,
                respawnRemaining = economyConfig.respawnTimeSeconds.toFloat(),
                speechText = "💀",
                speechUntilMs = System.currentTimeMillis() + 3000L,
            )
            attackerId?.let { killerId ->
                val reward = max(economyConfig.killReward, (victim.stars * economyConfig.killRewardPercent) / 100)
                receiveStars(killerId, reward, "Kill reward")
                val bountyReward = bounties.filter { it.targetID == victim.entityID }.sumOf { it.reward }
                if (bountyReward > 0) {
                    receiveStars(killerId, bountyReward, "Bounty reward")
                    bounties.removeAll { it.targetID == victim.entityID }
                }
                rememberAgent(killerId, MemoryEventType.Combat, "Killed ${victim.displayName} with ${weapon.displayName}.")
            }
        }
        agents[index] = updatedVictim
    }

    private fun updateHouseRest(agent: AgentEntity, delta: Float): AgentEntity {
        val house = findOwnHouse(agent)
        val onOwnHouse = house != null && tileX(agent) == house.tileX && tileY(agent) == house.tileY
        var updated = agent.copy(isRestingInHouse = onOwnHouse && agent.currentAction == AgentActionType.Idle)
        if (updated.hp > economyConfig.houseRestHpThreshold || !onOwnHouse || updated.currentAction != AgentActionType.Idle || updated.isDead) {
            return updated.copy(houseRestAccumulator = 0f)
        }
        val nextRest = updated.houseRestAccumulator + delta
        return if (nextRest >= 36_000f) {
            val healed = min(updated.maxHp, updated.hp + economyConfig.houseRestHealAmount)
            val gain = healed - updated.hp
            remember(updated.copy(hp = healed, houseRestAccumulator = 0f), MemoryEventType.Observe, "Rested in my house and healed $gain HP.")
        } else {
            updated.copy(houseRestAccumulator = nextRest)
        }
    }

    private fun moveOrWander(agent: AgentEntity, delta: Float): AgentEntity {
        val speed = effectiveMoveSpeed(agent)
        if (agent.targetX != null && agent.targetY != null) {
            val dx = agent.targetX - agent.x
            val dy = agent.targetY - agent.y
            val dist = hypot(dx, dy)
            if (dist < 2f) {
                return agent.copy(targetX = null, targetY = null, currentAction = AgentActionType.Idle)
            }
            val vx = dx / dist * speed
            val vy = dy / dist * speed
            return agent.copy(
                x = agent.x + vx * delta,
                y = agent.y + vy * delta,
                facingAngle = atan2(vy, vx),
            )
        }
        var timer = agent.wanderTimer - delta
        var idle = agent.wanderIdle
        var dx = agent.wanderDx
        var dy = agent.wanderDy
        var facing = agent.facingAngle
        if (timer <= 0f) {
            idle = !idle
            if (idle) {
                timer = 1f + random.nextFloat() * 2f
                dx = 0f
                dy = 0f
            } else {
                timer = 1f + random.nextFloat() * 3f
                val angle = random.nextFloat() * kotlin.math.PI.toFloat() * 2f
                dx = cos(angle)
                dy = sin(angle)
                facing = angle
            }
        }
        return if (idle) {
            agent.copy(wanderIdle = idle, wanderTimer = timer, wanderDx = dx, wanderDy = dy, facingAngle = facing)
        } else {
            agent.copy(
                x = agent.x + dx * speed * delta,
                y = agent.y + dy * speed * delta,
                wanderIdle = idle,
                wanderTimer = timer,
                wanderDx = dx,
                wanderDy = dy,
                facingAngle = facing,
            )
        }
    }

    private fun effectiveMoveSpeed(agent: AgentEntity): Float {
        var speed = agent.moveSpeed
        if (agent.isNearDeath) speed *= 0.5f
        if (isNight()) speed *= 0.7f
        return speed
    }

    private fun placeStructure(agent: AgentEntity, type: StructureType, tileX: Int, tileY: Int): AgentEntity {
        if (!canBuildOn(tileX, tileY)) {
            return remember(agent, MemoryEventType.Build, "Build failed: target tile is blocked or invalid.")
        }
        val cost = when (type) {
            StructureType.Wall -> economyConfig.wallCost
            StructureType.Trap -> economyConfig.trapCost
            StructureType.House -> economyConfig.houseCost
        }
        return if (spendStars(agent.entityID, cost, "Build ${type.displayName}")) {
            val hp = when (type) {
                StructureType.Wall -> economyConfig.wallHp
                StructureType.Trap -> economyConfig.trapHp
                StructureType.House -> economyConfig.houseHp
            }
            structures += StructureEntity(UUID.randomUUID().toString(), type, tileX, tileY, hp, agent.entityID)
            remember(
                agents.first { it.entityID == agent.entityID }.copy(buildCooldown = 1.5f, buildProgressSeconds = 0f),
                MemoryEventType.Build,
                "Built a ${type.displayName} at ($tileX, $tileY)."
            )
        } else {
            remember(agent, MemoryEventType.Build, "Build failed: not enough Stars.")
        }
    }

    private fun canBuildOn(tileX: Int, tileY: Int): Boolean {
        return TerrainGenerator.tileAt(tileX, tileY) !in setOf(TileType.DeepWater, TileType.Water) &&
            structures.none { it.tileX == tileX && it.tileY == tileY && it.hp > 0 } &&
            agents.none { !it.isDead && tileX(it) == tileX && tileY(it) == tileY }
    }

    private fun spendStars(agentId: String, amount: Int, reason: String): Boolean {
        if (amount <= 0) return false
        val index = agents.indexOfFirst { it.entityID == agentId }
        if (index < 0) return false
        val agent = agents[index]
        if (agent.stars < amount) return false
        val balance = agent.stars - amount
        agents[index] = remember(
            agent.copy(
                stars = balance,
                starTransactions = addStarTransaction(agent.starTransactions, -amount, reason, balance),
            ),
            MemoryEventType.Observe,
            "Spent $amount⭐ for $reason.",
        )
        return true
    }

    private fun receiveStars(agentId: String, amount: Int, reason: String) {
        if (amount <= 0) return
        updateAgentState(agentId) { agent ->
            val balance = agent.stars + amount
            remember(
                withSpeech(
                    agent.copy(
                        stars = balance,
                        starTransactions = addStarTransaction(agent.starTransactions, amount, reason, balance),
                    ),
                    "⭐ +$amount",
                ),
                MemoryEventType.Observe,
                "Received $amount⭐ from $reason.",
            )
        }
    }

    private fun transferStars(fromId: String, toId: String, amount: Int, reason: String): Boolean {
        if (!spendStars(fromId, amount, reason)) return false
        receiveStars(toId, amount, reason)
        return true
    }

    private fun consumeAmmo(agentId: String, weaponId: String): Boolean {
        if (weaponId in WeaponCatalog.defaultWeapons) return true
        val index = agents.indexOfFirst { it.entityID == agentId }
        if (index < 0) return false
        val ammo = agents[index].weaponAmmo[weaponId] ?: 0
        if (ammo <= 0) return false
        val next = agents[index].weaponAmmo.toMutableMap()
        if (ammo == 1) next.remove(weaponId) else next[weaponId] = ammo - 1
        agents[index] = agents[index].copy(weaponAmmo = next)
        return true
    }

    private fun addStarTransaction(current: List<StarTransaction>, amount: Int, reason: String, balance: Int): List<StarTransaction> {
        return (current + StarTransaction(System.currentTimeMillis(), amount, reason, balance)).takeLast(100)
    }

    private fun remember(agent: AgentEntity, type: MemoryEventType, content: String): AgentEntity {
        val nextMemories = (agent.memories + MemoryEntry(System.currentTimeMillis(), type, content)).takeLast(80)
        val nextLongTerm = distillLongTerm(agent.longTermMemories, type, content)
        return agent.copy(memories = nextMemories, longTermMemories = nextLongTerm)
    }

    private fun rememberAgent(agentId: String, type: MemoryEventType, content: String) {
        updateAgentState(agentId) { remember(it, type, content) }
    }

    private fun distillLongTerm(current: List<KnowledgeEntry>, type: MemoryEventType, content: String): List<KnowledgeEntry> {
        val category = when (type) {
            MemoryEventType.Combat -> KnowledgeCategory.Event
            MemoryEventType.Build -> KnowledgeCategory.Strategy
            MemoryEventType.Move -> KnowledgeCategory.Location
            MemoryEventType.Talk -> KnowledgeCategory.Social
            MemoryEventType.Observe -> KnowledgeCategory.Fact
        }
        val importance = when (type) {
            MemoryEventType.Combat -> 4
            MemoryEventType.Talk -> 3
            else -> 2
        }
        val next = (current + KnowledgeEntry(category, content.take(200), importance.toClampedImportance())).takeLast(50)
        return next
    }

    private fun withSpeech(agent: AgentEntity, text: String): AgentEntity {
        return agent.copy(speechText = text.take(60), speechUntilMs = System.currentTimeMillis() + 5000L)
    }

    private fun broadcastSpeech(speaker: AgentEntity, text: String) {
        agents.indices.forEach { index ->
            val listener = agents[index]
            if (listener.entityID == speaker.entityID || listener.isDead) return@forEach
            var updated = listener.copy(
                shortTermMessages = (listener.shortTermMessages + ShortTermMessage(speaker.displayName, text, System.currentTimeMillis())).takeLast(12),
                forceNextThink = true,
            )
            updated = remember(updated, MemoryEventType.Talk, "Heard ${speaker.displayName} say: \"$text\"")
            agents[index] = updated
        }
    }

    private fun updateAgentState(agentId: String, transform: (AgentEntity) -> AgentEntity) {
        val index = agents.indexOfFirst { it.entityID == agentId }
        if (index >= 0) {
            agents[index] = transform(agents[index])
        }
    }

    private fun resolveAgentByPrefix(prefix: String): AgentEntity? {
        if (prefix.isBlank()) return null
        val exact = agents.firstOrNull { it.entityID == prefix }
        if (exact != null) return exact
        val matches = agents.filter { it.entityID.startsWith(prefix) }
        return if (matches.size == 1) matches.first() else null
    }

    private fun nearestLivingTarget(x: Float, y: Float, excludingId: String): AgentEntity? {
        return agents.filter { it.entityID != excludingId && !it.isDead }
            .minByOrNull { hypot(it.x - x, it.y - y) }
    }

    private fun isAgentSheltered(agent: AgentEntity): Boolean {
        val house = findOwnHouse(agent) ?: return false
        return tileX(agent) == house.tileX && tileY(agent) == house.tileY && agent.currentAction == AgentActionType.Idle
    }

    private fun findOwnHouse(agent: AgentEntity): StructureEntity? {
        return structures.firstOrNull { it.type == StructureType.House && it.ownerID == agent.entityID && it.hp > 0 }
    }

    private fun distanceToStructure(x: Float, y: Float, structure: StructureEntity): Float {
        return hypot(centerX(structure.tileX) - x, centerY(structure.tileY) - y)
    }

    private fun allEntities(): List<Pair<String, String>> {
        val result = mutableListOf<Pair<String, String>>()
        agents.forEach {
            result += it.entityID to "${it.displayName} (HP:${it.hp}/${it.maxHp}) [${if (it.isDead) "dead_agent" else "agent"}] at (${tileX(it)}, ${tileY(it)})"
        }
        structures.forEach {
            val ownerSuffix = it.ownerID?.take(8)?.let { prefix -> " owner:$prefix" }.orEmpty()
            result += it.id to "${it.type.displayName} (HP:${it.hp}/${it.type.maxHp})$ownerSuffix at (${it.tileX}, ${it.tileY})"
        }
        return result
    }

    private fun expireOldTrades() {
        val now = System.currentTimeMillis()
        val expired = pendingTrades.filter { now - it.createdAt > economyConfig.tradeExpirationSeconds * 1000L }
        expired.forEach {
            receiveStars(it.offerorID, it.starsAmount, "Expired trade refund")
        }
        pendingTrades.removeAll(expired.toSet())
    }

    private fun updateTopBounty() {
        if (agents.size < 2) return
        val living = agents.sortedByDescending { it.stars }
        val leader = living.firstOrNull { it.stars > 0 } ?: return
        bounties.removeAll { it.posterID == "SYSTEM" && it.targetID != leader.entityID }
        if (bounties.none { it.posterID == "SYSTEM" && it.targetID == leader.entityID }) {
            bounties += Bounty(UUID.randomUUID().toString(), "SYSTEM", "⚔️ System", leader.entityID, leader.displayName, economyConfig.systemBountyReward, "#1 ranked — kill to claim bonus")
        }
    }

    fun leaderboard(): List<AgentEntity> = agents.sortedWith(compareByDescending<AgentEntity> { it.stars }.thenBy { it.displayName })

    private fun parseAction(value: String): AgentActionType {
        return when (value.lowercase()) {
            "move" -> AgentActionType.Move
            "build" -> AgentActionType.Build
            "attack" -> AgentActionType.Attack
            "talk" -> AgentActionType.Talk
            else -> AgentActionType.Idle
        }
    }

    private fun parseStructureType(value: String): StructureType {
        return when (value.lowercase()) {
            "trap" -> StructureType.Trap
            "house" -> StructureType.House
            else -> StructureType.Wall
        }
    }

    fun tileX(agent: AgentEntity): Int = floor(agent.x / StarsDefaults.TileSize).toInt()
    fun tileY(agent: AgentEntity): Int = floor(agent.y / StarsDefaults.TileSize).toInt()
    fun centerX(tileX: Int): Float = tileX * StarsDefaults.TileSize + StarsDefaults.TileSize / 2f
    fun centerY(tileY: Int): Float = tileY * StarsDefaults.TileSize + StarsDefaults.TileSize / 2f

    private fun respawn(agent: AgentEntity): AgentEntity {
        val restored = agent.copy(
            hp = agent.maxHp,
            respawnRemaining = 0f,
            currentAction = AgentActionType.Idle,
            targetX = null,
            targetY = null,
            speechText = "✨",
            speechUntilMs = System.currentTimeMillis() + 3000L,
            forceNextThink = true,
            nextThinkAtMs = System.currentTimeMillis() + 1500L,
        )
        return remember(restored, MemoryEventType.Combat, "Respawned with full HP.")
    }

    private fun saveSnapshot() {
        repo.saveWorldSnapshot(
            GameSnapshot(
                savedAt = System.currentTimeMillis(),
                agents = agents.toList(),
                structures = structures.toList(),
                camera = CameraSnapshot(cameraX, cameraY, cameraScale),
                customCommands = commandRegistry.customCommands(),
                dayOffset = worldDayOffset,
                pendingTrades = pendingTrades.toList(),
                bounties = bounties.toList(),
            )
        )
    }

    private fun restoreSnapshot(snapshot: GameSnapshot) {
        agents.clear()
        structures.clear()
        pendingTrades.clear()
        bounties.clear()
        commandRegistry.restore(snapshot.customCommands)
        agents.addAll(
            snapshot.agents.filterNot { it.entityID == "built-in-stardust" || it.modelConfigID == null }
        )
        structures.addAll(snapshot.structures)
        pendingTrades.addAll(snapshot.pendingTrades)
        bounties.addAll(snapshot.bounties)
        cameraX = snapshot.camera.x
        cameraY = snapshot.camera.y
        cameraScale = snapshot.camera.scale.coerceIn(0.45f, 1.85f)
        cameraTargetX = null
        cameraTargetY = null
        worldDayOffset = snapshot.dayOffset
    }

    private fun estimateTokens(text: String): Int = max(1, ceil(text.length / 4.0).toInt())

    private fun currentDayStamp(): String {
        val calendar = java.util.Calendar.getInstance()
        return "${calendar.get(java.util.Calendar.YEAR)}-${calendar.get(java.util.Calendar.DAY_OF_YEAR)}"
    }

    private fun colorForId(id: String): Int {
        val hue = (id.fold(0) { acc, c -> (acc * 31 + c.code) % 360 }).toFloat() / 360f
        val color = android.graphics.Color.HSVToColor(floatArrayOf(hue * 360f, 0.72f, 0.95f))
        return color
    }
}
