package com.qingteng.stars

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

private enum class SettingsPage {
    Menu,
    Agents,
    ProviderPicker,
    EditAgent,
    Subscription,
    Constitution,
    Commands,
    Economy,
    Sound,
    About,
}

private data class SettingsAlert(
    val title: String,
    val message: String,
    val confirmLabel: String = "确定",
    val dismissLabel: String? = null,
    val onConfirm: (() -> Unit)? = null,
)

private val SettingsBgDeep = Color(0xFF160F0B)
private val SettingsBgDark = Color(0xFF241A12)
private val SettingsBgCard = Color(0xFF2E2218)
private val SettingsBgRaised = Color(0xFF38291D)
private val SettingsBorder = Color(0xFF6E5234)
private val SettingsGold = Color(0xFFE7C164)
private val SettingsCream = Color(0xFFF0E7D1)
private val SettingsTan = Color(0xFFB79C6C)
private val SettingsMuted = Color(0xFF9A8361)

@Composable
fun IosSettingsOverlay(
    engine: StarsEngine,
    modifier: Modifier = Modifier,
) {
    var page by remember { mutableStateOf(SettingsPage.Menu) }
    var editingModel by remember { mutableStateOf<ModelConfig?>(null) }
    var creatingModel by remember { mutableStateOf(false) }
    var alertState by remember { mutableStateOf<SettingsAlert?>(null) }

    Box(
        modifier = modifier
            .background(SettingsBgDeep.copy(alpha = 0.86f))
            .padding(20.dp),
        contentAlignment = Alignment.Center,
    ) {
        ElevatedCard(
            modifier = Modifier
                .fillMaxWidth(0.9f)
                .fillMaxHeight(0.94f),
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgDark.copy(alpha = 0.97f)),
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(SettingsBgCard)
                        .padding(horizontal = 18.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (page != SettingsPage.Menu) {
                        TextButton(onClick = {
                            page = when (page) {
                                SettingsPage.Agents,
                                SettingsPage.Subscription,
                                SettingsPage.Constitution,
                                SettingsPage.Commands,
                                SettingsPage.Economy,
                                SettingsPage.Sound,
                                SettingsPage.About,
                                -> SettingsPage.Menu
                                SettingsPage.ProviderPicker,
                                SettingsPage.EditAgent,
                                -> SettingsPage.Agents
                                SettingsPage.Menu -> SettingsPage.Menu
                            }
                        }) {
                            Text("返回")
                        }
                    } else {
                        Spacer(modifier = Modifier.size(64.dp))
                    }

                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .padding(horizontal = 8.dp),
                    ) {
                        Text(settingsPageTitle(page), style = MaterialTheme.typography.displayMedium)
                        Text(settingsPageSubtitle(page), style = MaterialTheme.typography.bodySmall, color = SettingsTan)
                    }

                    TextButton(onClick = { engine.toggleSettings() }) {
                        Text("关闭")
                    }
                }

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 18.dp, vertical = 14.dp),
                ) {
                    when (page) {
                        SettingsPage.Menu -> SettingsMenuScreen(
                            onOpenAgents = { page = SettingsPage.Agents },
                            onOpenSubscription = { page = SettingsPage.Subscription },
                            onOpenConstitution = { page = SettingsPage.Constitution },
                            onOpenCommands = { page = SettingsPage.Commands },
                            onOpenEconomy = { page = SettingsPage.Economy },
                            onOpenSound = { page = SettingsPage.Sound },
                            onOpenAbout = { page = SettingsPage.About },
                        )

                        SettingsPage.Agents -> AgentRosterScreen(
                            engine = engine,
                            onAdd = {
                                when (val gate = engine.checkAddAgentGate()) {
                                    AddAgentGate.Allowed -> page = SettingsPage.ProviderPicker
                                    is AddAgentGate.RequireSpendQtc -> {
                                        alertState = SettingsAlert(
                                            title = "消耗 QTC",
                                            message = "当前已达到免费 Agent 上限 20。是否消耗 1 QTC 解锁一个额外槽位？当前余额 ${gate.balance}。",
                                            confirmLabel = "解锁",
                                            dismissLabel = "取消",
                                            onConfirm = {
                                                if (engine.spendQtcForAgentSlot()) {
                                                    page = SettingsPage.ProviderPicker
                                                }
                                            },
                                        )
                                    }
                                    is AddAgentGate.RequireQtcPurchase -> {
                                        alertState = SettingsAlert(
                                            title = "Agent 槽位已满",
                                            message = "当前已达到免费上限，且 QTC 余额为 ${gate.balance}。请前往关于页面补充 QTC。",
                                            confirmLabel = "前往关于",
                                            dismissLabel = "取消",
                                            onConfirm = { page = SettingsPage.About },
                                        )
                                    }
                                }
                            },
                            onEdit = { config ->
                                editingModel = config
                                creatingModel = false
                                page = SettingsPage.EditAgent
                            },
                        )

                        SettingsPage.ProviderPicker -> ProviderPickerScreen(
                            engine = engine,
                            onSelect = { provider ->
                                val error = engine.checkProviderSelection(provider)
                                if (error != null) {
                                    alertState = SettingsAlert(title = "无法添加", message = error)
                                } else {
                                    editingModel = engine.createBlankModel(provider)
                                    creatingModel = true
                                    page = SettingsPage.EditAgent
                                }
                            },
                        )

                        SettingsPage.EditAgent -> {
                            val model = editingModel
                            if (model != null) {
                                AgentEditorScreen(
                                    engine = engine,
                                    model = model,
                                    isNew = creatingModel,
                                    onSaved = {
                                        page = SettingsPage.Agents
                                        creatingModel = false
                                        editingModel = null
                                    },
                                    onDeleted = {
                                        page = SettingsPage.Agents
                                        creatingModel = false
                                        editingModel = null
                                    },
                                    onAlert = { alertState = it },
                                )
                            }
                        }

                        SettingsPage.Subscription -> SubscriptionScreen(engine = engine)
                        SettingsPage.Constitution -> TextEditorScreen(
                            title = "Constitution",
                            value = engine.constitution,
                            onSave = engine::updateConstitution,
                            minLines = 10,
                        )
                        SettingsPage.Commands -> TextEditorScreen(
                            title = "Commands",
                            value = engine.commandsText,
                            onSave = engine::updateCommandsText,
                            minLines = 12,
                        )
                        SettingsPage.Economy -> TextEditorScreen(
                            title = "Economy",
                            value = engine.economyText,
                            onSave = engine::updateEconomyText,
                            minLines = 12,
                        )
                        SettingsPage.Sound -> SoundSettingsScreen(engine = engine)
                        SettingsPage.About -> AboutScreen(engine = engine)
                    }
                }
            }
        }

        alertState?.let { alert ->
            AlertDialog(
                onDismissRequest = { alertState = null },
                title = { Text(alert.title) },
                text = { Text(alert.message) },
                confirmButton = {
                    TextButton(
                        onClick = {
                            val action = alert.onConfirm
                            alertState = null
                            action?.invoke()
                        },
                    ) {
                        Text(alert.confirmLabel)
                    }
                },
                dismissButton = if (alert.dismissLabel != null) {
                    {
                        TextButton(onClick = { alertState = null }) {
                            Text(alert.dismissLabel)
                        }
                    }
                } else {
                    null
                },
            )
        }
    }
}

@Composable
private fun SettingsMenuScreen(
    onOpenAgents: () -> Unit,
    onOpenSubscription: () -> Unit,
    onOpenConstitution: () -> Unit,
    onOpenCommands: () -> Unit,
    onOpenEconomy: () -> Unit,
    onOpenSound: () -> Unit,
    onOpenAbout: () -> Unit,
) {
    val items = listOf(
        Triple("Agent management", "Agent roster, provider selection, SOUL and memory editing", onOpenAgents),
        Triple("Subscription", "Tier switching, official provider availability, QTC status", onOpenSubscription),
        Triple("Constitution", "World constitution editor", onOpenConstitution),
        Triple("Commands", "Command registry prompt editor", onOpenCommands),
        Triple("Economy", "Economy configuration editor", onOpenEconomy),
        Triple("Sound", "BGM / SFX settings", onOpenSound),
        Triple("About", "Project information and local QTC tools", onOpenAbout),
    )

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            SettingsInfoCard(
                title = "iOS-style settings flow",
                body = "这里不再使用旧的 tab 弹层，而是按 iOS 原项目的方式拆成菜单、Agent roster、provider picker 和 provider-specific 编辑页。",
            )
        }
        items(items) { (title, subtitle, action) ->
            SettingsMenuCard(
                title = title,
                subtitle = subtitle,
                onClick = action,
            )
        }
    }
}

@Composable
private fun AgentRosterScreen(
    engine: StarsEngine,
    onAdd: () -> Unit,
    onEdit: (ModelConfig) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            SettingsInfoCard(
                title = "Agent summary",
                body = "当前订阅 ${engine.subscriptionTier.displayName} · Agent 总数 ${engine.modelConfigs.size} · 自建槽位 ${engine.qtcState.maxAgents} · QTC 余额 ${engine.qtcState.balance}",
                actionLabel = "新增 Agent",
                onAction = onAdd,
            )
        }
        items(engine.modelConfigs, key = { it.id }) { config ->
            val agent = engine.agentForConfig(config.id)
            val soul = agent?.soul ?: SoulDocument()
            val soulSummary = listOf(soul.personality, soul.beliefs, soul.goals)
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .joinToString(" · ")
                .ifBlank { "SOUL 未形成" }
            val status = engine.connectionStatusFor(config)
            val message = engine.connectionMessageFor(config)
            ElevatedCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onEdit(config) },
                colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
                shape = RoundedCornerShape(18.dp),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(settingsStatusColor(status)),
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(config.alias, style = MaterialTheme.typography.titleLarge)
                            Text(
                                "${config.provider.displayName} · ${config.modelName}",
                                style = MaterialTheme.typography.bodySmall,
                                color = SettingsTan,
                            )
                        }
                        if (engine.isAgentPaused(config)) {
                            SettingsPill("Paused", SettingsBorder.copy(alpha = 0.7f))
                        }
                    }

                    Text(
                        soulSummary,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFFE7DFC9),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        message,
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF98A3B4),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        SettingsPill("CTX ${agent?.latestContextUsage?.percentageText ?: "0%"}")
                        SettingsPill("Tokens ${formatCompactTokens(agent?.totalTokensUsed ?: 0)}")
                        SettingsPill(if (config.id == BuiltInAgent.stableId) "Built-in" else "Agent")
                    }
                }
            }
        }
    }
}

@Composable
private fun ProviderPickerScreen(
    engine: StarsEngine,
    onSelect: (APIProvider) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    val visibleProviders = remember(engine.subscriptionTier, query, engine.modelConfigs.size) {
        engine.visibleProviders().filter { provider ->
            val haystack = listOf(
                provider.displayName,
                provider.definition.selectionTitle,
                provider.definition.selectionSubtitle,
                provider.definition.protocolLabel,
            ).joinToString(" ").lowercase()
            haystack.contains(query.trim().lowercase())
        }
    }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("搜索 provider") },
            singleLine = true,
        )

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(visibleProviders, key = { it.name }) { provider ->
                ElevatedCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onSelect(provider) },
                    colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
                    shape = RoundedCornerShape(18.dp),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        SettingsPill(provider.definition.protocolLabel, SettingsBgRaised)
                        Column(modifier = Modifier.weight(1f)) {
                            Text(provider.definition.selectionTitle, style = MaterialTheme.typography.titleMedium)
                            Text(
                                provider.definition.selectionSubtitle,
                                style = MaterialTheme.typography.bodySmall,
                                color = SettingsTan,
                            )
                        }
                        Text("▸", style = MaterialTheme.typography.titleLarge, color = Color(0xFFE4C25E))
                    }
                }
            }
        }
    }
}

@Composable
private fun AgentEditorScreen(
    engine: StarsEngine,
    model: ModelConfig,
    isNew: Boolean,
    onSaved: () -> Unit,
    onDeleted: () -> Unit,
    onAlert: (SettingsAlert) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val agent = engine.agentForConfig(model.id)
    val provider = model.provider
    val isBuiltIn = engine.isBuiltInConfig(model)
    val isOfficial = provider.isOfficialProvider
    val officialShowsModelPicker = provider == APIProvider.StarsPlus || provider == APIProvider.StarsPro || provider == APIProvider.StarsMax

    var alias by remember(model.id, model.alias) { mutableStateOf(model.alias) }
    var apiKey by remember(model.id, model.apiKey) { mutableStateOf(model.apiKey) }
    var baseUrl by remember(model.id, model.baseUrl) { mutableStateOf(model.baseUrl) }
    var modelName by remember(model.id, model.modelName) { mutableStateOf(model.modelName.ifBlank { engine.defaultModel(provider) }) }
    var appendV1 by remember(model.id, model.appendV1) { mutableStateOf(model.appendV1) }
    var connectionStatus by remember(model.id, model.connectionStatus, engine.subscriptionTier, engine.qtcState) {
        mutableStateOf(engine.connectionStatusFor(model))
    }
    var connectionMessage by remember(model.id, model.connectionMessage, engine.subscriptionTier, engine.qtcState) {
        mutableStateOf(engine.connectionMessageFor(model))
    }
    var fetchedModels by remember(model.id, provider, engine.subscriptionTier) { mutableStateOf(engine.providerModels(provider)) }
    var showModelDialog by remember(model.id) { mutableStateOf(false) }
    var isLoading by remember(model.id) { mutableStateOf(false) }

    var personality by remember(model.id, agent?.soul?.personality) { mutableStateOf(agent?.soul?.personality.orEmpty()) }
    var beliefs by remember(model.id, agent?.soul?.beliefs) { mutableStateOf(agent?.soul?.beliefs.orEmpty()) }
    var goals by remember(model.id, agent?.soul?.goals) { mutableStateOf(agent?.soul?.goals.orEmpty()) }
    var journal by remember(model.id, agent?.soul?.journal) { mutableStateOf(agent?.soul?.journal.orEmpty()) }

    val availableModels = if (isOfficial) engine.providerModels(provider) else fetchedModels
    val memoryCount = agent?.longTermMemories?.size ?: 0

    fun draftConfig(): ModelConfig {
        val resolvedAlias = alias.trim().ifBlank { provider.displayName }
        val resolvedModel = modelName.trim().ifBlank { engine.defaultModel(provider).ifBlank { provider.definition.defaultModel } }
        val resolvedAppendV1 = if (isOfficial) provider.definition.defaultAppendV1 else appendV1
        return model.copy(
            alias = if (isBuiltIn && !isNew) model.alias else resolvedAlias,
            baseUrl = if (isBuiltIn && !isNew) model.baseUrl else baseUrl.trim(),
            modelName = if (isBuiltIn && !isNew) model.modelName else resolvedModel,
            apiKey = if (isOfficial || (isBuiltIn && !isNew)) model.apiKey else apiKey.trim(),
            appendV1 = if (isBuiltIn && !isNew) model.appendV1 else resolvedAppendV1,
            connectionStatus = connectionStatus,
            connectionMessage = connectionMessage,
        )
    }

    fun saveModel() {
        if (!isBuiltIn && !isOfficial && apiKey.trim().isBlank()) {
            onAlert(SettingsAlert("缺少 API Key", "第三方 provider 需要填写 API Key。"))
            return
        }
        val draft = draftConfig()
        engine.saveModel(draft)
        if (!isNew) {
            engine.saveSoul(
                draft.id,
                SoulDocument(
                    personality = personality.trim(),
                    beliefs = beliefs.trim(),
                    goals = goals.trim(),
                    journal = journal.trim(),
                ),
            )
        }
        onSaved()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (!isOfficial) {
            SettingsProviderCard(
                title = provider.definition.selectionTitle,
                subtitle = provider.definition.selectionSubtitle,
                protocol = provider.definition.protocolLabel,
                auth = provider.definition.authLabel,
                modelSource = provider.definition.modelSourceLabel,
                contextWindow = provider.definition.contextWindowTokens,
                docsUrl = provider.definition.docsURL,
                onOpenDocs = {
                    if (provider.definition.docsURL.isNotBlank()) {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(provider.definition.docsURL)))
                    }
                },
            )
        } else {
            val body = if (officialShowsModelPicker) {
                "需要订阅 ${provider.requiredSubscriptionTier.displayName}。当前 provider 上限 ${provider.officialAgentLimit} 个。\n\n${engine.providerModels(provider).joinToString("\n")}"
            } else {
                "免费官方模型，由开发者提供。当前 provider 上限 ${provider.officialAgentLimit} 个。"
            }
            SettingsInfoCard(title = provider.definition.selectionTitle, body = body)
        }

        SettingsEditableCard(
            title = "Alias",
            value = alias,
            onValueChange = { alias = it },
            enabled = !isBuiltIn,
            singleLine = true,
        )

        if (!isBuiltIn && !isOfficial) {
            SettingsEditableCard(
                title = "API Key",
                value = apiKey,
                onValueChange = { apiKey = it },
                singleLine = true,
            )
            SettingsEditableCard(
                title = "Base URL",
                value = baseUrl,
                onValueChange = { baseUrl = it },
                singleLine = true,
            )
            SettingsToggleRow(
                title = "自动追加 /v1",
                value = appendV1,
                onToggle = { appendV1 = it },
            )
        }

        ElevatedCard(
            colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
            shape = RoundedCornerShape(18.dp),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(settingsStatusColor(connectionStatus)),
                    )
                    Text(connectionStatus.displayText, style = MaterialTheme.typography.titleMedium)
                }
                Text(connectionMessage, style = MaterialTheme.typography.bodySmall, color = SettingsMuted)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (!isBuiltIn || isOfficial) {
                        OutlinedButton(
                            onClick = {
                                isLoading = true
                                scope.launch {
                                    val result = engine.testConnection(draftConfig())
                                    connectionStatus = result.status
                                    connectionMessage = result.message
                                    fetchedModels = if (isOfficial) engine.providerModels(provider) else result.models
                                    isLoading = false
                                }
                            },
                            enabled = !isLoading,
                        ) {
                            Text(if (isLoading) "Testing..." else "Test Connection")
                        }
                    }
                    if (!isBuiltIn && !isOfficial) {
                        OutlinedButton(
                            onClick = {
                                isLoading = true
                                scope.launch {
                                    runCatching { engine.listModels(draftConfig()) }
                                        .onSuccess { models ->
                                            fetchedModels = models
                                            connectionStatus = ConnectionStatus.Success
                                            connectionMessage = if (models.isEmpty()) "未返回模型列表，你仍可手动填写模型名。" else "已获取 ${models.size} 个模型。"
                                            showModelDialog = models.isNotEmpty()
                                        }
                                        .onFailure { error ->
                                            connectionStatus = ConnectionStatus.Failure
                                            connectionMessage = error.message ?: "模型列表获取失败"
                                            onAlert(SettingsAlert("获取模型失败", connectionMessage))
                                        }
                                    isLoading = false
                                }
                            },
                            enabled = !isLoading,
                        ) {
                            Text("Refresh Models")
                        }
                    }
                }
            }
        }

        if (isOfficial) {
            if (officialShowsModelPicker) {
                SettingsInfoCard(
                    title = "Model",
                    body = modelName.ifBlank { engine.defaultModel(provider) },
                    actionLabel = "选择模型",
                    onAction = { showModelDialog = availableModels.isNotEmpty() },
                )
            } else {
                SettingsInfoCard(
                    title = "Model",
                    body = engine.defaultModel(provider),
                )
            }
        } else {
            SettingsEditableCard(
                title = "Model",
                value = modelName,
                onValueChange = { modelName = it },
                enabled = !isBuiltIn,
                singleLine = true,
            )
            if (!isBuiltIn) {
                SettingsInfoCard(
                    title = "Model picker",
                    body = if (availableModels.isEmpty()) "当前没有可选模型，可先测试连接或手动填写模型名。" else "已获取 ${availableModels.size} 个可选模型。",
                    actionLabel = "选择模型",
                    onAction = { showModelDialog = availableModels.isNotEmpty() },
                )
            }
        }

        if (!isNew) {
            SettingsEditableCard(title = "Personality", value = personality, onValueChange = { personality = it }, minLines = 3)
            SettingsEditableCard(title = "Beliefs", value = beliefs, onValueChange = { beliefs = it }, minLines = 3)
            SettingsEditableCard(title = "Goals", value = goals, onValueChange = { goals = it }, minLines = 3)
            SettingsEditableCard(title = "Journal", value = journal, onValueChange = { journal = it }, minLines = 4)
            SettingsInfoCard(
                title = "Memory",
                body = "Long-term memory count: $memoryCount",
                actionLabel = "Clear memory",
                onAction = { engine.clearLongTermMemory(model.id) },
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(onClick = { saveModel() }) {
                Text(if (isNew) "Add Agent" else "Save")
            }
            if (!isNew && !isBuiltIn) {
                OutlinedButton(
                    onClick = {
                        onAlert(
                            SettingsAlert(
                                title = "删除 Agent",
                                message = "确认删除 ${model.alias} 吗？这会一并移除它的长期记忆与配置。",
                                confirmLabel = "删除",
                                dismissLabel = "取消",
                                onConfirm = {
                                    engine.clearLongTermMemory(model.id)
                                    engine.deleteModel(model.id)
                                    onDeleted()
                                },
                            ),
                        )
                    },
                ) {
                    Text("Delete")
                }
            }
        }
    }

    if (showModelDialog) {
        AlertDialog(
            onDismissRequest = { showModelDialog = false },
            title = { Text("选择模型") },
            text = {
                Column(
                    modifier = Modifier
                        .heightIn(max = 320.dp)
                        .verticalScroll(rememberScrollState()),
                ) {
                    availableModels.take(30).forEach { candidate ->
                        Text(
                            candidate,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    modelName = candidate
                                    showModelDialog = false
                                }
                                .padding(vertical = 10.dp),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        HorizontalDivider(color = Color(0x223B4254))
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showModelDialog = false }) {
                    Text("关闭")
                }
            },
        )
    }
}

@Composable
private fun SubscriptionScreen(engine: StarsEngine) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            SettingsInfoCard(
                title = "Current tier",
                body = "当前订阅等级：${engine.subscriptionTier.displayName}\n官方 provider 的显示、官方 Agent 的可用数量，以及超限 Agent 的 pause 规则都由这里控制。",
            )
        }
        item {
            ElevatedCard(
                colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
                shape = RoundedCornerShape(18.dp),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text("Tier switch", style = MaterialTheme.typography.titleLarge)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        SubscriptionTier.entries.forEach { tier ->
                            val selected = engine.subscriptionTier == tier
                            val color = if (selected) SettingsBgRaised else SettingsBgDark
                            Surface(
                                modifier = Modifier.clickable { engine.updateSubscriptionTier(tier) },
                                shape = RoundedCornerShape(999.dp),
                                color = color,
                            ) {
                                Text(
                                    tier.displayName,
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                                    style = MaterialTheme.typography.bodySmall,
                                )
                            }
                        }
                    }
                }
            }
        }
        item {
            SettingsInfoCard(
                title = "QTC",
                body = "余额 ${engine.qtcState.balance} · 已消耗 ${engine.qtcState.totalSpent} · 自建 Agent 上限 ${engine.qtcState.maxAgents}",
            )
        }
        item {
            SettingsInfoCard(
                title = "Official provider limits",
                body = "QingTeng 5 个 · Stars Plus 10 个 · Stars Pro 5 个 · Stars Max 3 个",
            )
        }
    }
}

@Composable
private fun TextEditorScreen(
    title: String,
    value: String,
    onSave: (String) -> Unit,
    minLines: Int,
) {
    var text by remember(value) { mutableStateOf(value) }
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SettingsEditableCard(
            title = title,
            value = text,
            onValueChange = { text = it },
            minLines = minLines,
        )
        Button(onClick = { onSave(text) }) {
            Text("保存")
        }
    }
}

@Composable
private fun SoundSettingsScreen(engine: StarsEngine) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ElevatedCard(
            colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
            shape = RoundedCornerShape(18.dp),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text("BGM", style = MaterialTheme.typography.titleLarge)
                Text("Volume ${"%.2f".format(engine.bgmVolume)}", style = MaterialTheme.typography.bodyMedium)
                Slider(value = engine.bgmVolume, onValueChange = engine::updateBgmVolume)
                Text("SFX ${"%.2f".format(engine.sfxVolume)}", style = MaterialTheme.typography.bodyMedium)
                Slider(value = engine.sfxVolume, onValueChange = engine::updateSfxVolume)
            }
        }
        SettingsInfoCard(
            title = "BGM Source",
            body = "当前 Android 端默认使用 Built-in Tracks。iOS 的 Apple Music 授权与歌单选择结构已在布局上保留，但 Android 版本暂未接入 Apple Music。",
        )
        SettingsInfoCard(
            title = "Track List",
            body = "Moon and Sun\nEverything Moves\nLitae\n\nMusic credit: fiftysounds.com",
        )
        SettingsInfoCard(
            title = "World stats",
            body = "天气 ${settingsWeatherLabel(engine.weatherEffect)} · 交易 ${engine.pendingTrades.size} · 悬赏 ${engine.bounties.size} · 建筑 ${engine.structures.size}",
        )
    }
}

@Composable
private fun AboutScreen(engine: StarsEngine) {
    val context = LocalContext.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ElevatedCard(
            colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
            shape = RoundedCornerShape(18.dp),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(18.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("Stars", style = MaterialTheme.typography.displayMedium, color = SettingsGold)
                Text("Android port", style = MaterialTheme.typography.titleMedium, color = SettingsTan)
                Text(engine.aboutText, style = MaterialTheme.typography.bodyMedium, color = SettingsCream)
            }
        }
        SettingsInfoCard(
            title = "Open Source",
            body = "Android 端继续保持与 iOS 一样的开源入口说明。",
            actionLabel = "GitHub",
            onAction = {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/nicktmro/Stars")))
            },
        )
        SettingsInfoCard(
            title = "Music Credits",
            body = "Moon and Sun\nEverything Moves\nLitae\n\nCredits from fiftysounds.com",
            actionLabel = "fiftysounds.com",
            onAction = {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.fiftysounds.com")))
            },
        )
        SettingsInfoCard(
            title = "Android local build",
            body = "当前 Android 端已接入 iOS 的 provider / tier / QTC / built-in 星尘 / pause 逻辑。由于本地包未接 Play Billing，这里保留临时 QTC 按钮用于验证 20+QTC 槽位逻辑。",
        )
        SettingsInfoCard(
            title = "QTC Dashboard",
            body = buildString {
                appendLine("Balance ${engine.qtcState.balance}")
                appendLine("Total spent ${engine.qtcState.totalSpent}")
                if (engine.qtcState.transactions.isEmpty()) {
                    append("暂无 QTC 交易记录")
                } else {
                    engine.qtcState.transactions.takeLast(6).reversed().forEach { tx ->
                        val sign = if (tx.amount > 0) "+" else ""
                        appendLine("$sign${tx.amount} · ${tx.reason} · 余额 ${tx.balance}")
                    }
                }
            },
        )
        ElevatedCard(
            colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
            shape = RoundedCornerShape(18.dp),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text("Local QTC tools", style = MaterialTheme.typography.titleLarge)
                Text("当前余额 ${engine.qtcState.balance}", style = MaterialTheme.typography.bodyMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedButton(onClick = { engine.addQtcCredits(1, "本地测试 +1 QTC") }) {
                        Text("+1 QTC")
                    }
                    OutlinedButton(onClick = { engine.addQtcCredits(5, "本地测试 +5 QTC") }) {
                        Text("+5 QTC")
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsMenuCard(
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    ElevatedCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
        shape = RoundedCornerShape(18.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = SettingsTan)
            }
            Text("▸", style = MaterialTheme.typography.titleLarge, color = Color(0xFFE4C25E))
        }
    }
}

@Composable
private fun SettingsProviderCard(
    title: String,
    subtitle: String,
    protocol: String,
    auth: String,
    modelSource: String,
    contextWindow: Int,
    docsUrl: String,
    onOpenDocs: () -> Unit,
) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleLarge)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = SettingsTan)
            SettingsPill("Protocol $protocol", SettingsBgRaised)
            SettingsPill("Auth $auth", Color(0xFF405032))
            SettingsPill("Model source $modelSource", Color(0xFF513726))
            SettingsPill("Context ${formatCompactTokens(contextWindow)}", Color(0xFF4A3A31))
            if (docsUrl.isNotBlank()) {
                OutlinedButton(onClick = onOpenDocs) {
                    Text("打开文档")
                }
            }
        }
    }
}

@Composable
private fun SettingsEditableCard(
    title: String,
    value: String,
    onValueChange: (String) -> Unit,
    enabled: Boolean = true,
    singleLine: Boolean = false,
    minLines: Int = 1,
) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier.fillMaxWidth(),
                enabled = enabled,
                singleLine = singleLine,
                minLines = minLines,
                maxLines = if (singleLine) 1 else minLines + 6,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SettingsGold,
                    unfocusedBorderColor = SettingsBorder,
                    disabledBorderColor = SettingsBorder.copy(alpha = 0.5f),
                    focusedTextColor = SettingsCream,
                    unfocusedTextColor = SettingsCream,
                    disabledTextColor = SettingsMuted,
                    focusedContainerColor = SettingsBgDark,
                    unfocusedContainerColor = SettingsBgDark,
                    disabledContainerColor = SettingsBgDark.copy(alpha = 0.7f),
                    focusedLabelColor = SettingsGold,
                    unfocusedLabelColor = SettingsTan,
                ),
            )
        }
    }
}

@Composable
private fun SettingsToggleRow(
    title: String,
    value: Boolean,
    onToggle: (Boolean) -> Unit,
) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
        shape = RoundedCornerShape(18.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(title, modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            OutlinedButton(onClick = { onToggle(!value) }) {
                Text(if (value) "开启" else "关闭")
            }
        }
    }
}

@Composable
private fun SettingsInfoCard(
    title: String,
    body: String,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = SettingsBgCard),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleLarge)
            Text(body, style = MaterialTheme.typography.bodyMedium, color = SettingsCream)
            if (actionLabel != null && onAction != null) {
                OutlinedButton(onClick = onAction) {
                    Text(actionLabel)
                }
            }
        }
    }
}

@Composable
private fun SettingsPill(
    text: String,
    color: Color = SettingsBgRaised,
) {
    Surface(
        shape = RoundedCornerShape(999.dp),
        color = color,
    ) {
        Text(
            text,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            style = MaterialTheme.typography.bodySmall,
        )
    }
}

private fun settingsPageTitle(page: SettingsPage): String = when (page) {
    SettingsPage.Menu -> "设置"
    SettingsPage.Agents -> "Agent management"
    SettingsPage.ProviderPicker -> "Choose provider"
    SettingsPage.EditAgent -> "Edit Agent"
    SettingsPage.Subscription -> "Subscription"
    SettingsPage.Constitution -> "Constitution"
    SettingsPage.Commands -> "Commands"
    SettingsPage.Economy -> "Economy"
    SettingsPage.Sound -> "Sound"
    SettingsPage.About -> "About"
}

private fun settingsPageSubtitle(page: SettingsPage): String = when (page) {
    SettingsPage.Menu -> "模型、规则、经济、音频与说明"
    SettingsPage.Agents -> "iOS roster-style agent list"
    SettingsPage.ProviderPicker -> "官方 provider 受订阅等级过滤"
    SettingsPage.EditAgent -> "provider-specific configuration"
    SettingsPage.Subscription -> "tier / QTC / pause logic"
    SettingsPage.Constitution -> "world constitution editor"
    SettingsPage.Commands -> "command registry editor"
    SettingsPage.Economy -> "economy configuration editor"
    SettingsPage.Sound -> "BGM / SFX / world status"
    SettingsPage.About -> "project info and local tools"
}

private fun settingsStatusColor(status: ConnectionStatus): Color = when (status) {
    ConnectionStatus.Unknown -> Color(0xFFE4C25E)
    ConnectionStatus.Success -> Color(0xFF8FD887)
    ConnectionStatus.Failure -> Color(0xFFFF8671)
    ConnectionStatus.Paused -> Color(0xFF8F9DB1)
}

private fun settingsWeatherLabel(effect: WeatherEffect): String = when (effect) {
    WeatherEffect.Clear -> "晴朗"
    WeatherEffect.Rain -> "雨"
    WeatherEffect.HeavyRain -> "暴雨"
    WeatherEffect.Snow -> "雪"
    WeatherEffect.Thunderstorm -> "雷暴"
    WeatherEffect.Fog -> "雾"
}
