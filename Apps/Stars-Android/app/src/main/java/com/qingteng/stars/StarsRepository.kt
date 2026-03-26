package com.qingteng.stars

import android.content.Context
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import java.io.File
import java.io.InputStreamReader
import java.util.UUID

class StarsRepository(private val context: Context) {
    private val prefs = context.getSharedPreferences("stars_android", Context.MODE_PRIVATE)
    private val gson: Gson = GsonBuilder().create()
    private val baseDir = File(context.filesDir, "stars").apply { mkdirs() }
    private val snapshotFile = File(baseDir, "world_snapshot.json")
    private val env by lazy { loadEnv() }

    fun loadModels(): List<ModelConfig> {
        val raw = prefs.getString("models", null) ?: return emptyList()
        return runCatching {
            gson.fromJson(raw, Array<ModelConfig>::class.java)?.toList() ?: emptyList()
        }.getOrDefault(emptyList())
    }

    fun saveModels(models: List<ModelConfig>) {
        prefs.edit().putString("models", gson.toJson(models)).apply()
    }

    fun loadSubscriptionTier(): SubscriptionTier {
        val raw = prefs.getString("subscription_tier", SubscriptionTier.Free.name) ?: SubscriptionTier.Free.name
        return runCatching { SubscriptionTier.valueOf(raw) }.getOrDefault(SubscriptionTier.Free)
    }

    fun saveSubscriptionTier(value: SubscriptionTier) {
        prefs.edit().putString("subscription_tier", value.name).apply()
    }

    fun loadQtcState(): QtcState {
        val raw = prefs.getString("qtc_state", null) ?: return QtcState()
        return runCatching { gson.fromJson(raw, QtcState::class.java) ?: QtcState() }.getOrDefault(QtcState())
    }

    fun saveQtcState(value: QtcState) {
        prefs.edit().putString("qtc_state", gson.toJson(value)).apply()
    }

    fun loadConstitution(): String = prefs.getString("constitution", StarsDefaults.Constitution) ?: StarsDefaults.Constitution
    fun saveConstitution(value: String) = prefs.edit().putString("constitution", value).apply()

    fun loadCommands(): String = prefs.getString("commands", StarsDefaults.Commands) ?: StarsDefaults.Commands
    fun saveCommands(value: String) = prefs.edit().putString("commands", value).apply()

    fun loadEconomy(): String = prefs.getString("economy", StarsDefaults.Economy) ?: StarsDefaults.Economy
    fun saveEconomy(value: String) = prefs.edit().putString("economy", value).apply()

    fun loadAbout(): String = prefs.getString("about", StarsDefaults.About) ?: StarsDefaults.About

    fun loadBgmVolume(): Float = prefs.getFloat("bgm_volume", 0.1f)
    fun saveBgmVolume(value: Float) = prefs.edit().putFloat("bgm_volume", value).apply()

    fun loadSfxVolume(): Float = prefs.getFloat("sfx_volume", 0.4f)
    fun saveSfxVolume(value: Float) = prefs.edit().putFloat("sfx_volume", value).apply()

    fun loadBgmSource(): BgmSource {
        return runCatching {
            BgmSource.valueOf(prefs.getString("bgm_source", BgmSource.BuiltIn.name) ?: BgmSource.BuiltIn.name)
        }.getOrDefault(BgmSource.BuiltIn)
    }

    fun saveBgmSource(value: BgmSource) = prefs.edit().putString("bgm_source", value.name).apply()

    fun loadWorldSnapshot(): GameSnapshot? {
        if (!snapshotFile.exists()) return null
        return runCatching {
            gson.fromJson(snapshotFile.readText(), GameSnapshot::class.java)
        }.getOrNull()
    }

    fun saveWorldSnapshot(snapshot: GameSnapshot) {
        snapshotFile.writeText(gson.toJson(snapshot))
    }

    fun newModel(provider: APIProvider = APIProvider.OpenAI): ModelConfig {
        return ModelConfig(
            id = UUID.randomUUID().toString(),
            alias = "Agent ${loadModels().size + 1}",
            provider = provider,
            baseUrl = "",
            modelName = defaultModel(provider).ifBlank { provider.defaultModel.ifBlank { "gpt-4.1-mini" } },
            appendV1 = provider.definition.defaultAppendV1,
        )
    }

    fun envValue(key: String): String = env[key].orEmpty()

    fun envCsv(key: String): List<String> {
        return envValue(key)
            .split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
    }

    fun officialApiKey(provider: APIProvider): String = OfficialProviderConfig.apiKey(this, provider)

    fun officialModels(provider: APIProvider): List<String> = OfficialProviderConfig.models(this, provider)

    fun defaultModel(provider: APIProvider): String {
        return when {
            provider.isOfficialProvider -> OfficialProviderConfig.defaultModel(this, provider)
            else -> provider.definition.defaultModel
        }
    }

    fun providerCatalogModels(provider: APIProvider): List<String> {
        return when {
            provider.isOfficialProvider -> officialModels(provider)
            else -> provider.definition.catalogModels
        }
    }

    fun builtInSeedConfig(): ModelConfig? {
        val apiKey = envValue("OPENROUTER_KEY")
        if (apiKey.isBlank()) return null
        return ModelConfig(
            id = BuiltInAgent.stableId,
            alias = BuiltInAgent.alias,
            provider = APIProvider.OpenRouter,
            baseUrl = "",
            modelName = envValue("MODEL").ifBlank { "openrouter/free" },
            apiKey = apiKey,
            appendV1 = APIProvider.OpenRouter.definition.defaultAppendV1,
        )
    }

    private fun loadEnv(): Map<String, String> {
        return runCatching {
            context.assets.open("stars-env").use { stream ->
                InputStreamReader(stream).use { reader ->
                    reader.readText()
                }
            }
        }.getOrDefault("").lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
            .mapNotNull { line ->
                val index = line.indexOf('=')
                if (index <= 0) return@mapNotNull null
                val key = line.substring(0, index).trim()
                val value = line.substring(index + 1).trim()
                key to value
            }
            .toMap()
    }
}
