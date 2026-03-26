package com.qingteng.stars

import android.graphics.Paint
import android.graphics.Typeface
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

class MainActivity : ComponentActivity() {
    private lateinit var audioController: StarsAudioController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val repo = StarsRepository(applicationContext)
        val engine = StarsEngine(repo, lifecycleScope)
        audioController = StarsAudioController(this)
        audioController.setBgmVolume(engine.bgmVolume)
        audioController.setSfxVolume(engine.sfxVolume)
        audioController.start(engine.bgmSource)
        engine.onPlayWeaponSfx = { weaponId -> audioController.playWeapon(weaponId) }

        setContent {
            StarsAndroidTheme {
                StarsGameRoot(
                    engine = engine,
                    audioController = audioController,
                )
            }
        }
    }

    override fun onStart() {
        super.onStart()
        if (::audioController.isInitialized) {
            audioController.resumeBgm()
        }
    }

    override fun onStop() {
        if (::audioController.isInitialized) {
            audioController.pauseBgm()
        }
        super.onStop()
    }

    override fun onDestroy() {
        if (::audioController.isInitialized) {
            audioController.release()
        }
        super.onDestroy()
    }
}

@Composable
private fun StarsAndroidTheme(
    content: @Composable () -> Unit,
) {
    val pixelDisplay = FontFamily(Font(R.font.fusion_pixel_prop))
    val pixelMono = FontFamily(Font(R.font.fusion_pixel_mono))
    val scheme = darkColorScheme(
        primary = Color(0xFFE7C164),
        onPrimary = Color(0xFF211503),
        secondary = Color(0xFF74A36A),
        tertiary = Color(0xFF8B6447),
        background = Color(0xFF160F0B),
        surface = Color(0xFF2D2117),
        surfaceVariant = Color(0xFF3B2C20),
        onBackground = Color(0xFFF0E7D1),
        onSurface = Color(0xFFF0E7D1),
        outline = Color(0xFF6E5234),
        error = Color(0xFFD35E4A),
    )
    androidx.compose.material3.MaterialTheme(
        colorScheme = scheme,
        typography = androidx.compose.material3.Typography(
            displayMedium = TextStyle(fontFamily = pixelDisplay, fontSize = 28.sp, lineHeight = 32.sp),
            headlineSmall = TextStyle(fontFamily = pixelDisplay, fontSize = 20.sp, lineHeight = 24.sp),
            titleLarge = TextStyle(fontFamily = pixelDisplay, fontSize = 18.sp, lineHeight = 22.sp),
            titleMedium = TextStyle(fontFamily = pixelDisplay, fontSize = 15.sp, lineHeight = 18.sp),
            bodyLarge = TextStyle(fontFamily = pixelMono, fontSize = 13.sp, lineHeight = 18.sp),
            bodyMedium = TextStyle(fontFamily = pixelMono, fontSize = 12.sp, lineHeight = 17.sp),
            bodySmall = TextStyle(fontFamily = pixelMono, fontSize = 11.sp, lineHeight = 15.sp),
            labelLarge = TextStyle(fontFamily = pixelDisplay, fontSize = 12.sp, lineHeight = 16.sp),
            labelMedium = TextStyle(fontFamily = pixelDisplay, fontSize = 11.sp, lineHeight = 14.sp),
        ),
        content = content,
    )
}

@Composable
private fun StarsGameRoot(
    engine: StarsEngine,
    audioController: StarsAudioController,
) {
    var previousFrame by remember { mutableStateOf<Long?>(null) }
    val selectedAgent = engine.selectedAgent()
    var chatAnimatedAgent by remember { mutableStateOf<AgentEntity?>(selectedAgent) }

    SideEffect {
        audioController.setBgmVolume(engine.bgmVolume)
        audioController.setSfxVolume(engine.sfxVolume)
        audioController.start(engine.bgmSource)
    }

    LaunchedEffect(selectedAgent) {
        if (selectedAgent != null) {
            chatAnimatedAgent = selectedAgent
        }
    }

    LaunchedEffect(engine) {
        while (isActive) {
            withFrameNanos { frameTime ->
                val last = previousFrame
                previousFrame = frameTime
                val delta = if (last == null) 0.016f else ((frameTime - last) / 1_000_000_000f).coerceIn(0.001f, 0.05f)
                engine.step(delta)
            }
        }
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF140F0B))
    ) {
        val chatWidth = (maxWidth * 0.52f).coerceIn(340.dp, 560.dp)
        val leaderboardWidth = 288.dp
        val density = LocalDensity.current
        val chatWidthPx = with(density) { chatWidth.toPx() }
        val chatFocusOffset = chatWidthPx * 0.5f * engine.cameraScale

        GameWorldCanvas(
            engine = engine,
            focusOffsetX = chatFocusOffset,
            modifier = Modifier.fillMaxSize(),
        )

        Row(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(start = 10.dp, top = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            HudButton(iconRes = R.drawable.ic_hud_settings, contentDescription = "设置", onClick = { engine.toggleSettings() })
            HudButton(iconRes = R.drawable.ic_hud_find, contentDescription = "查找", onClick = { engine.focusNextAgent(chatFocusOffset) })
            HudButton(iconRes = R.drawable.ic_hud_leaderboard, contentDescription = "排行榜", onClick = { engine.toggleLeaderboard() })
        }

        Surface(
            color = Color(0xCC20170F),
            shape = RoundedCornerShape(8.dp),
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(end = 10.dp, top = 10.dp)
                .border(2.dp, Color(0xFF6D5331), RoundedCornerShape(8.dp))
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(engine.clockText(), style = MaterialTheme.typography.titleMedium, color = Color(0xFFF0E7D1))
                Text(
                    "天气 ${weatherLabel(engine.weatherEffect)}",
                    color = weatherTint(engine.weatherEffect),
                    style = MaterialTheme.typography.bodySmall,
                )
                Text(
                    if (engine.isNight()) "夜晚" else "白天",
                    color = if (engine.isNight()) Color(0xFF9FAED7) else Color(0xFFFFD36A),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }

        AnimatedVisibility(
            visible = engine.showLeaderboard,
            modifier = Modifier.align(Alignment.CenterStart),
            enter = fadeIn() + slideInHorizontally { -it / 2 },
            exit = fadeOut() + slideOutHorizontally { -it / 3 },
        ) {
            LeaderboardPanel(
                engine = engine,
                cameraOffsetX = chatFocusOffset,
                modifier = Modifier
                    .padding(start = 10.dp, top = 70.dp, bottom = 20.dp)
                    .width(leaderboardWidth)
                    .fillMaxHeight(0.86f),
            )
        }

        AnimatedVisibility(
            visible = selectedAgent != null,
            modifier = Modifier.align(Alignment.CenterEnd),
            enter = fadeIn() + slideInHorizontally { it / 2 },
            exit = fadeOut() + slideOutHorizontally { it / 3 },
        ) {
            chatAnimatedAgent?.let { visibleAgent ->
                AgentChatPanel(
                    engine = engine,
                    agent = visibleAgent,
                    modifier = Modifier
                        .padding(top = 4.dp)
                        .width(chatWidth)
                        .fillMaxHeight(),
                )
            }
        }

        if (engine.showSettings) {
            IosSettingsOverlay(
                engine = engine,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@Composable
private fun HudButton(
    iconRes: Int,
    contentDescription: String,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        shape = RoundedCornerShape(6.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(6.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color(0xCC261E13),
            contentColor = Color(0xFFF2DDA0),
        ),
        modifier = Modifier
            .size(48.dp)
            .border(2.dp, Color(0xFF6D5331), RoundedCornerShape(6.dp)),
    ) {
        Image(
            painter = painterResource(iconRes),
            contentDescription = contentDescription,
            modifier = Modifier.fillMaxSize(),
        )
    }
}

@Composable
private fun GameWorldCanvas(
    engine: StarsEngine,
    focusOffsetX: Float,
    modifier: Modifier = Modifier,
) {
    var viewport by remember { mutableStateOf(IntSize.Zero) }
    val namePaint = remember {
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color(0xFFF6ECD1).toArgb()
            textAlign = Paint.Align.CENTER
            textSize = 18f
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
        }
    }
    val smallPaint = remember {
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color(0xFF111111).toArgb()
            textAlign = Paint.Align.CENTER
            textSize = 15f
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
        }
    }
    val sleepPaint = remember {
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color(0xFFF1D790).toArgb()
            textAlign = Paint.Align.CENTER
            textSize = 18f
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
        }
    }

    Canvas(
        modifier = modifier
            .onSizeChanged { viewport = it }
            .pointerInput(viewport, engine.cameraScale) {
                detectTransformGestures { _, pan, zoom, _ ->
                    engine.pan(pan.x, pan.y)
                    if (abs(zoom - 1f) > 0.01f) {
                        engine.zoom(zoom)
                    }
                }
            }
            .pointerInput(viewport, engine.cameraX, engine.cameraY, engine.cameraScale) {
                detectTapGestures { tap ->
                    if (viewport.width == 0 || viewport.height == 0) return@detectTapGestures
                    val worldTap = screenToWorld(tap, viewport, engine)
                    if (!engine.selectAgentNear(worldTap.x, worldTap.y, focusOffsetX)) {
                        engine.closeChat()
                    }
                }
            }
    ) {
        if (viewport.width == 0 || viewport.height == 0) return@Canvas

        drawRect(
            brush = Brush.verticalGradient(
                colors = listOf(Color(0xFF111729), Color(0xFF0A0E18), Color(0xFF05070F)),
            )
        )

        val tileWorld = StarsDefaults.TileSize
        val worldWidth = size.width * engine.cameraScale
        val worldHeight = size.height * engine.cameraScale
        val halfWorldWidth = worldWidth / 2f
        val halfWorldHeight = worldHeight / 2f
        val minTileX = floor((engine.cameraX - halfWorldWidth) / tileWorld).toInt() - 2
        val maxTileX = ceil((engine.cameraX + halfWorldWidth) / tileWorld).toInt() + 2
        val minTileY = floor((engine.cameraY - halfWorldHeight) / tileWorld).toInt() - 2
        val maxTileY = ceil((engine.cameraY + halfWorldHeight) / tileWorld).toInt() + 2

        for (tileY in minTileY..maxTileY) {
            for (tileX in minTileX..maxTileX) {
                val tileType = TerrainGenerator.tileAt(tileX, tileY)
                val screenTopLeft = worldToScreen(
                    worldX = tileX * tileWorld,
                    worldY = tileY * tileWorld + tileWorld,
                    viewport = viewport,
                    engine = engine,
                )
                val tileSizePx = tileWorld / engine.cameraScale
                drawRect(
                    color = if ((tileX + tileY) and 1 == 0) tileType.baseColor else tileType.altColor,
                    topLeft = Offset(screenTopLeft.x, screenTopLeft.y),
                    size = Size(tileSizePx + 0.6f, tileSizePx + 0.6f),
                )
                tileType.detailColor?.let { detail ->
                    val detailSize = max(1.6f, tileSizePx * 0.15f)
                    drawCircle(
                        color = detail,
                        radius = detailSize,
                        center = Offset(screenTopLeft.x + tileSizePx * 0.72f, screenTopLeft.y + tileSizePx * 0.32f),
                    )
                    drawCircle(
                        color = detail.copy(alpha = 0.8f),
                        radius = detailSize * 0.7f,
                        center = Offset(screenTopLeft.x + tileSizePx * 0.26f, screenTopLeft.y + tileSizePx * 0.68f),
                    )
                }
            }
        }

        val sortedStructures = engine.structures.sortedBy { it.tileY }
        val groundStructures = sortedStructures.filter { it.type != StructureType.House }
        val houses = sortedStructures.filter { it.type == StructureType.House }
        groundStructures.forEach { structure ->
            drawStructure(structure, engine, viewport)
        }

        val sortedAgents = engine.agents.sortedBy { it.y }
        val restingAgents = sortedAgents.filter { it.isRestingInHouse && !it.isDead }
        val activeAgents = sortedAgents.filterNot { it.isRestingInHouse && !it.isDead }
        val restingLayouts = linkedMapOf<String, AgentRenderInfo>()
        restingAgents.forEach { agent ->
            drawAgentBody(agent, engine, viewport)?.let { layout ->
                restingLayouts[agent.entityID] = layout
            }
        }

        houses.forEach { structure ->
            drawStructure(structure, engine, viewport)
        }

        engine.projectiles.forEach { projectile ->
            drawProjectile(projectile, engine, viewport)
        }

        activeAgents.forEach { agent ->
            drawAgentBody(agent, engine, viewport)?.let { layout ->
                drawAgentOverlay(agent, engine, viewport, layout, namePaint, smallPaint, sleepPaint)
            }
        }
        restingAgents.forEach { agent ->
            restingLayouts[agent.entityID]?.let { layout ->
                drawAgentOverlay(agent, engine, viewport, layout, namePaint, smallPaint, sleepPaint)
            }
        }

        drawWeatherOverlay(engine.weatherEffect, viewport, engine)

        val (ambientColor, ambientAlpha) = engine.ambientOverlay()
        if (ambientAlpha > 0f) {
            drawRect(ambientColor.copy(alpha = ambientAlpha))
        }

        drawGridVignette(viewport)
    }
}

private data class AgentRenderInfo(
    val center: Offset,
    val spriteSize: Float,
)

private fun DrawScope.drawStructure(
    structure: StructureEntity,
    engine: StarsEngine,
    viewport: IntSize,
) {
    val center = worldToScreen(engine.centerX(structure.tileX), engine.centerY(structure.tileY), viewport, engine)
    val tilePx = StarsDefaults.TileSize / engine.cameraScale
    val half = tilePx * 0.48f
    val rect = Rect(
        left = center.x - half,
        top = center.y - half,
        right = center.x + half,
        bottom = center.y + half,
    )

    when (structure.type) {
        StructureType.Wall -> {
            drawRoundRect(
                color = Color(0xFF65717C),
                topLeft = rect.topLeft,
                size = rect.size,
                cornerRadius = CornerRadius(3f, 3f),
            )
            drawRoundRect(
                color = Color(0xFFA7B0B9),
                topLeft = Offset(rect.left + half * 0.2f, rect.top + half * 0.15f),
                size = Size(rect.width * 0.6f, rect.height * 0.24f),
                cornerRadius = CornerRadius(2f, 2f),
            )
        }
        StructureType.Trap -> {
            val path = Path().apply {
                moveTo(center.x, rect.top)
                lineTo(rect.right, center.y)
                lineTo(center.x, rect.bottom)
                lineTo(rect.left, center.y)
                close()
            }
            drawPath(path, Color(0xFFB03A33))
            drawPath(path, Color(0xFFFFD285), style = Stroke(width = max(1f, tilePx * 0.08f)))
        }
        StructureType.House -> {
            drawRoundRect(
                color = Color(0xFF704A33),
                topLeft = Offset(rect.left, rect.top + rect.height * 0.25f),
                size = Size(rect.width, rect.height * 0.75f),
                cornerRadius = CornerRadius(3f, 3f),
            )
            val roof = Path().apply {
                moveTo(rect.left - half * 0.08f, rect.top + rect.height * 0.35f)
                lineTo(center.x, rect.top - half * 0.15f)
                lineTo(rect.right + half * 0.08f, rect.top + rect.height * 0.35f)
                close()
            }
            drawPath(roof, Color(0xFFB95F43))
            drawRoundRect(
                color = Color(0xFFDAB874),
                topLeft = Offset(center.x - rect.width * 0.12f, rect.top + rect.height * 0.52f),
                size = Size(rect.width * 0.24f, rect.height * 0.32f),
                cornerRadius = CornerRadius(2f, 2f),
            )
        }
    }

    val hpWidth = rect.width
    val ratio = structure.hp.toFloat() / structure.type.maxHp.toFloat()
    drawRoundRect(
        color = Color(0x99000000),
        topLeft = Offset(rect.left, rect.top - 8f),
        size = Size(hpWidth, 4f),
        cornerRadius = CornerRadius(2f, 2f),
    )
    drawRoundRect(
        color = lerp(Color(0xFFDE604D), Color(0xFF89D27C), ratio.coerceIn(0f, 1f)),
        topLeft = Offset(rect.left, rect.top - 8f),
        size = Size(hpWidth * ratio.coerceIn(0f, 1f), 4f),
        cornerRadius = CornerRadius(2f, 2f),
    )
}

private fun DrawScope.drawProjectile(
    projectile: ProjectileEntity,
    engine: StarsEngine,
    viewport: IntSize,
) {
    val weapon = WeaponCatalog.weapon(projectile.weaponId)
    val center = worldToScreen(projectile.x, projectile.y, viewport, engine)
    val radius = max(2f, weapon.projectileSize.toFloat()) / max(0.7f, engine.cameraScale)
    drawCircle(
        color = weapon.color,
        radius = radius,
        center = center,
    )
    if (weapon.aoeRadius > 0f) {
        drawCircle(
            color = weapon.color.copy(alpha = 0.25f),
            radius = radius * 1.8f,
            center = center,
        )
    }
}

private fun DrawScope.drawAgentBody(
    agent: AgentEntity,
    engine: StarsEngine,
    viewport: IntSize,
): AgentRenderInfo? {
    val center = worldToScreen(agent.x, agent.y, viewport, engine)
    val scale = engine.cameraScale
    val spriteSize = max(16f, StarsDefaults.AgentSize / scale)
    if (center.x < -60f || center.x > viewport.width + 60f || center.y < -60f || center.y > viewport.height + 60f) {
        return null
    }

    val shadowColor = if (agent.isDead) Color(0x66000000) else Color(0x55201010)
    val bodyAlpha = if (agent.isRestingInHouse && !agent.isDead) 0.45f else 1f
    val isMoving = !agent.isDead && (
        agent.currentAction == AgentActionType.Move ||
            (!agent.wanderIdle) ||
            (agent.targetX != null && agent.targetY != null)
        )
    val motion = creatureMotion(agent.entityID, spriteSize, isMoving)
    val renderCenter = Offset(center.x, center.y + motion.bobY)

    drawOval(
        color = shadowColor.copy(alpha = if (bodyAlpha < 1f) 0.28f else shadowColor.alpha),
        topLeft = Offset(renderCenter.x - spriteSize * 0.32f, renderCenter.y + spriteSize * 0.22f),
        size = Size(spriteSize * 0.64f, spriteSize * 0.22f),
    )

    drawPixelCreature(
        seed = agent.entityID,
        baseColorArgb = agent.agentColorArgb,
        center = center,
        spriteSize = spriteSize,
        alpha = if (agent.isDead) 0.38f else bodyAlpha,
        motion = motion,
    )

    if (agent.isDead) {
        drawLine(
            color = Color(0xFF301010).copy(alpha = bodyAlpha),
            start = Offset(renderCenter.x - spriteSize * 0.34f, renderCenter.y - spriteSize * 0.34f),
            end = Offset(renderCenter.x + spriteSize * 0.34f, renderCenter.y + spriteSize * 0.34f),
            strokeWidth = max(2f, spriteSize * 0.12f),
            cap = StrokeCap.Round,
        )
        drawLine(
            color = Color(0xFF301010).copy(alpha = bodyAlpha),
            start = Offset(renderCenter.x + spriteSize * 0.34f, renderCenter.y - spriteSize * 0.34f),
            end = Offset(renderCenter.x - spriteSize * 0.34f, renderCenter.y + spriteSize * 0.34f),
            strokeWidth = max(2f, spriteSize * 0.12f),
            cap = StrokeCap.Round,
        )
    }

    if (!agent.isDead && agent.currentAction == AgentActionType.Attack) {
        drawCircle(
            color = Color(0xFFFFBC54).copy(alpha = 0.6f * bodyAlpha),
            radius = spriteSize * 0.12f,
            center = Offset(
                renderCenter.x + kotlin.math.cos(agent.facingAngle) * spriteSize * 0.34f,
                renderCenter.y - kotlin.math.sin(agent.facingAngle) * spriteSize * 0.18f,
            ),
        )
    }
    return AgentRenderInfo(center = renderCenter, spriteSize = spriteSize)
}

private fun DrawScope.drawAgentOverlay(
    agent: AgentEntity,
    engine: StarsEngine,
    viewport: IntSize,
    layout: AgentRenderInfo,
    namePaint: Paint,
    bubblePaint: Paint,
    sleepPaint: Paint,
) {
    val center = layout.center
    val spriteSize = layout.spriteSize
    val hpRatio = (agent.hp.toFloat() / agent.maxHp.toFloat()).coerceIn(0f, 1f)
    val hpBarWidth = spriteSize * 0.9f
    if (agent.isNearDeath) {
        val pulseAlpha = (0.18f + ((kotlin.math.sin(System.currentTimeMillis() / 180.0) + 1.0) * 0.18).toFloat())
        drawCircle(
            color = Color(0xFFD96043).copy(alpha = pulseAlpha),
            radius = spriteSize * 0.92f,
            center = center,
            style = Stroke(width = max(2f, spriteSize * 0.12f)),
        )
    }
    if (engine.selectedAgentId == agent.entityID) {
        drawCircle(
            color = Color(0x99F7E08A),
            radius = spriteSize * 0.76f,
            center = center,
            style = Stroke(width = max(2f, spriteSize * 0.1f)),
        )
    }

    drawRoundRect(
        color = Color(0x99000000),
        topLeft = Offset(center.x - hpBarWidth / 2f, center.y - spriteSize * 0.72f),
        size = Size(hpBarWidth, 5f),
        cornerRadius = CornerRadius(2f, 2f),
    )
    drawRoundRect(
        color = lerp(Color(0xFFDE604D), Color(0xFF89D27C), hpRatio),
        topLeft = Offset(center.x - hpBarWidth / 2f, center.y - spriteSize * 0.72f),
        size = Size(hpBarWidth * hpRatio, 5f),
        cornerRadius = CornerRadius(2f, 2f),
    )

    drawContext.canvas.nativeCanvas.drawText(
        agent.displayName,
        center.x,
        center.y - spriteSize * 1.1f,
        namePaint,
    )

    if (agent.isRestingInHouse && !agent.isDead) {
        val sleepFloat = kotlin.math.sin(System.currentTimeMillis() / 350.0).toFloat() * 4f
        drawContext.canvas.nativeCanvas.drawText(
            "ZZZ",
            center.x,
            center.y - spriteSize * 1.7f + sleepFloat,
            sleepPaint,
        )
    }

    agent.speechText?.takeIf { it.isNotBlank() }?.let { speech ->
        val bubbleWidth = min(viewport.width * 0.32f, max(110f, speech.length * 8f))
        val bubbleRect = Rect(
            left = center.x - bubbleWidth / 2f,
            top = center.y - spriteSize * 1.88f,
            right = center.x + bubbleWidth / 2f,
            bottom = center.y - spriteSize * 1.28f,
        )
        drawRoundRect(
            color = Color(0xDDEAD7A8),
            topLeft = bubbleRect.topLeft,
            size = bubbleRect.size,
            cornerRadius = CornerRadius(12f, 12f),
        )
        drawRoundRect(
            color = Color(0x88291608),
            topLeft = bubbleRect.topLeft,
            size = bubbleRect.size,
            cornerRadius = CornerRadius(12f, 12f),
            style = Stroke(width = 2f),
        )
        drawContext.canvas.nativeCanvas.drawText(
            speech.take(28),
            center.x,
            bubbleRect.center.y + 5f,
            bubblePaint,
        )
    }
}

private fun DrawScope.drawWeatherOverlay(
    weather: WeatherEffect,
    viewport: IntSize,
    engine: StarsEngine,
) {
    val minuteStamp = engine.currentHour() * 60 + engine.currentMinute()
    when (weather) {
        WeatherEffect.Rain, WeatherEffect.HeavyRain, WeatherEffect.Thunderstorm -> {
            val density = if (weather == WeatherEffect.HeavyRain) 56 else 34
            repeat(density) { index ->
                val x = ((index * 41 + minuteStamp * 13) % (viewport.width + 120)) - 60
                val y = ((index * 59 + minuteStamp * 31) % (viewport.height + 120)) - 60
                drawLine(
                    color = if (weather == WeatherEffect.Thunderstorm) Color(0xAAE1F2FF) else Color(0x88B9D7F0),
                    start = Offset(x.toFloat(), y.toFloat()),
                    end = Offset(x + 10f, y + 24f),
                    strokeWidth = 2f,
                )
            }
            if (weather == WeatherEffect.Thunderstorm && minuteStamp % 7 == 0) {
                drawRect(Color.White.copy(alpha = 0.08f))
            }
        }
        WeatherEffect.Fog -> {
            repeat(8) { index ->
                val radius = viewport.width * (0.12f + index * 0.015f)
                val x = ((index * 87 + minuteStamp * 9) % max(1, viewport.width)).toFloat()
                val y = ((index * 51 + minuteStamp * 5) % max(1, viewport.height)).toFloat()
                drawCircle(
                    color = Color(0x26DDE8EE),
                    radius = radius,
                    center = Offset(x, y),
                )
            }
        }
        WeatherEffect.Snow -> {
            repeat(28) { index ->
                val x = ((index * 67 + minuteStamp * 8) % max(1, viewport.width)).toFloat()
                val y = ((index * 43 + minuteStamp * 3) % max(1, viewport.height)).toFloat()
                drawCircle(Color(0xDDEFF5FF), radius = 2.5f, center = Offset(x, y))
            }
        }
        WeatherEffect.Clear -> Unit
    }
}

private fun DrawScope.drawGridVignette(viewport: IntSize) {
    drawRect(
        brush = Brush.radialGradient(
            colors = listOf(Color.Transparent, Color(0x66050A12)),
            center = Offset(viewport.width / 2f, viewport.height / 2f),
            radius = max(viewport.width, viewport.height).toFloat() * 0.72f,
        )
    )
}

@Composable
private fun LeaderboardPanel(
    engine: StarsEngine,
    cameraOffsetX: Float,
    modifier: Modifier = Modifier,
) {
    val rankings = engine.leaderboard()

    ElevatedCard(
        modifier = modifier.border(2.dp, Color(0xFFBA8C37), RoundedCornerShape(18.dp)),
        colors = CardDefaults.elevatedCardColors(containerColor = Color(0xF0221811)),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF1B130C))
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("⭐ 排行榜", modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleLarge, color = Color(0xFFE9C667))
                TextButton(onClick = { engine.toggleLeaderboard() }) {
                    Text("✕", color = Color(0xFFF1E2B7))
                }
            }

            Text(
                "🎯 #1 自动悬赏 10⭐ · 点击名字查看",
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF23170D))
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFFD26B46),
                textAlign = TextAlign.Center,
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0x88312216))
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text("#", modifier = Modifier.width(28.dp), style = MaterialTheme.typography.labelLarge, color = Color(0xFF9E7F5A))
                Text("Agent", modifier = Modifier.weight(1f), style = MaterialTheme.typography.labelLarge, color = Color(0xFF9E7F5A))
                Text("Stars", style = MaterialTheme.typography.labelLarge, color = Color(0xFF9E7F5A))
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
            ) {
                itemsIndexed(rankings, key = { _, item -> item.entityID }) { index, agent ->
                    val isLeader = index == 0 && rankings.size > 1 && agent.stars > 0
                    val medal = when (index) {
                        0 -> "🥇"
                        1 -> "🥈"
                        2 -> "🥉"
                        else -> "${index + 1}."
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { focusAgent(engine, agent, cameraOffsetX) }
                            .background(if (isLeader) Color(0x18E4C25E) else Color.Transparent)
                            .padding(horizontal = 10.dp, vertical = 9.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            medal,
                            modifier = Modifier.width(28.dp),
                            textAlign = TextAlign.Center,
                            color = when (index) {
                                0 -> Color(0xFFE4C25E)
                                1 -> Color(0xFFC3CDD8)
                                2 -> Color(0xFFC88F63)
                                else -> MaterialTheme.colorScheme.onSurface
                            },
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                if (agent.isDead) "💀${agent.displayName}" else agent.displayName,
                                color = if (agent.isDead) Color(0xFFAA9B91) else MaterialTheme.colorScheme.onSurface,
                                style = MaterialTheme.typography.bodyLarge,
                            )
                            Text(
                                buildString {
                                    append(if (agent.isDead) "已死亡" else actionLabel(agent.currentAction))
                                    if (isLeader) append(" · 🎯")
                                },
                                style = MaterialTheme.typography.bodySmall,
                                color = if (isLeader) Color(0xFFD26B46) else Color(0xFF9F8566),
                            )
                        }
                        Text(
                            "${agent.stars}⭐",
                            style = MaterialTheme.typography.titleMedium,
                            color = Color(0xFFE4C25E),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AgentChatPanel(
    engine: StarsEngine,
    agent: AgentEntity,
    modifier: Modifier = Modifier,
) {
    var detailTab by remember(agent.entityID) { mutableIntStateOf(0) }
    var detailExpanded by remember(agent.entityID) { mutableStateOf(false) }
    var input by remember(agent.entityID) { mutableStateOf("") }
    val chatScroll = rememberScrollState()
    val detailScroll = rememberScrollState()
    val panelShape = RoundedCornerShape(topStart = 20.dp, bottomStart = 20.dp)
    val visibleMessages = agent.chatMessages
        .filter { it.speaker != ChatSpeakerRole.System }
        .takeLast(30)
    val hpRatio = (agent.hp.toFloat() / agent.maxHp.toFloat()).coerceIn(0f, 1f)
    val hpColor = when {
        hpRatio > 0.5f -> Color(0xFF63B13E)
        hpRatio > 0.25f -> Color(0xFFD5B33C)
        else -> Color(0xFFD96043)
    }
    val contextText = agent.latestContextUsage?.let {
        "🧠 ${it.usedTokens}/${it.limitTokens} (${it.percentageText})"
    } ?: "等待思考"
    val contextColor = agent.latestContextUsage?.let {
        when {
            it.usageRatio > 0.8f -> Color(0xFFD96043)
            it.usageRatio > 0.6f -> Color(0xFFD5B33C)
            else -> Color(0xFF6AA2C2)
        }
    } ?: Color(0xFF9E8662)
    val totalK = if (agent.totalTokensUsed > 1000) {
        String.format("%.1fK", agent.totalTokensUsed / 1000.0)
    } else {
        agent.totalTokensUsed.toString()
    }
    val modelName = engine.modelConfigs.firstOrNull { it.id == agent.modelConfigID }?.modelName
        ?: if (agent.isBuiltIn) "Built-in" else "Unknown"

    LaunchedEffect(agent.chatMessages.size, agent.pendingOwnerReplies) {
        delay(50)
        chatScroll.scrollTo(chatScroll.maxValue)
    }

    ElevatedCard(
        modifier = modifier.border(3.dp, Color(0xFF6A4D2D), panelShape),
        shape = panelShape,
        colors = CardDefaults.elevatedCardColors(containerColor = Color(0xF0221811)),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF332418)),
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(agent.displayName, style = MaterialTheme.typography.titleLarge, color = Color(0xFFE9C667))
                        Text(
                            buildString {
                                append(modelName)
                                if (agent.pendingOwnerReplies > 0) append(" · 正在思考")
                                if (agent.isDead) append(" · 已死亡")
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFFBDA989),
                        )
                    }
                    TextButton(onClick = { engine.closeChat() }) {
                        Text("✕", color = Color(0xFFF1E2B7))
                    }
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(2.dp)
                        .background(Color(0xFF5C442D))
                )
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0x99D7C08A))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "❤️ ${agent.hp}/${agent.maxHp} ⭐${agent.stars}",
                        style = MaterialTheme.typography.bodySmall,
                        color = hpColor,
                    )
                    SpacerWeight()
                    Text(
                        "📍(${engine.tileX(agent)},${engine.tileY(agent)})",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFFBDA989),
                    )
                    SpacerWeight()
                    Text(
                        if (agent.isDead) "☠ dead" else "⚡ ${actionLabel(agent.currentAction)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFFBDA989),
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        contextText,
                        style = MaterialTheme.typography.bodySmall,
                        color = contextColor,
                    )
                    SpacerWeight()
                    Text(
                        "🪙 $totalK · 💭×${agent.thinkCycleCount}",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFFD49E47),
                    )
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(Color(0x77523B27))
                )
            }

            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 10.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color(0xA0443222))
                    .border(1.dp, Color(0x886A4D2D), RoundedCornerShape(16.dp))
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(chatScroll)
                        .padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    if (visibleMessages.isEmpty()) {
                        Text("还没有对话。给主人发送消息后，这里会实时刷新。", color = Color(0xFFC2B39A))
                    } else {
                        visibleMessages.forEach { message ->
                            val isOwner = message.speaker == ChatSpeakerRole.Owner
                            val bubbleColor = if (isOwner) Color(0xFF2F455A) else Color(0xFF433122)
                            val bubbleBorder = if (isOwner) Color(0xFF6D93B0) else Color(0xFF6B5233)
                            Column(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalAlignment = if (isOwner) Alignment.End else Alignment.Start,
                            ) {
                                Surface(
                                    color = bubbleColor,
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier
                                        .widthIn(max = 320.dp)
                                        .border(1.dp, bubbleBorder, RoundedCornerShape(12.dp)),
                                ) {
                                    Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp)) {
                                        Text(
                                            if (isOwner) "主人" else agent.displayName,
                                            color = Color(0xFFF0DDA2),
                                            style = MaterialTheme.typography.labelLarge,
                                        )
                                        Text(message.text, style = MaterialTheme.typography.bodyMedium, color = Color(0xFFF0E7D1))
                                    }
                                }
                            }
                        }
                    }
                    if (agent.pendingOwnerReplies > 0) {
                        Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.Start) {
                            Surface(
                                color = Color(0xFF433122),
                                shape = RoundedCornerShape(12.dp),
                            ) {
                                Text(
                                    "··· ${agent.displayName} 正在思考",
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = Color(0xFFD3BE90),
                                )
                            }
                        }
                    }
                }
            }

            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 10.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .clickable { detailExpanded = !detailExpanded },
                color = Color(0x3326150D),
            ) {
                Text(
                    if (detailExpanded) "收起日志 ▲" else "展开日志 ▼",
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 10.dp, vertical = 8.dp),
                    color = Color(0xFFD3BE90),
                    style = MaterialTheme.typography.labelLarge,
                )
            }

            if (detailExpanded) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(Color(0xFF21180F))
                        .border(1.dp, Color(0x886A4D2D), RoundedCornerShape(14.dp)),
                ) {
                    TabRow(
                        selectedTabIndex = detailTab,
                        containerColor = Color(0xFF2A1D12),
                        contentColor = Color(0xFFF0E7D1),
                    ) {
                        listOf("日志", "Stars").forEachIndexed { index, label ->
                            Tab(
                                selected = detailTab == index,
                                onClick = { detailTab = index },
                                text = { Text(label) },
                            )
                        }
                    }

                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 150.dp, max = 270.dp)
                            .verticalScroll(detailScroll)
                            .padding(horizontal = 12.dp, vertical = 10.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        when (detailTab) {
                            0 -> {
                                InfoSection("当前思考", agent.currentThought ?: "暂无")
                                InfoSection(
                                    "记忆",
                                    if (agent.memories.isEmpty()) "暂无"
                                    else agent.memories.takeLast(18).joinToString("\n") { "• ${it.content}" }
                                )
                                InfoSection(
                                    "长期记忆",
                                    if (agent.longTermMemories.isEmpty()) "暂无"
                                    else agent.longTermMemories.takeLast(12).joinToString("\n") { "• ${it.content}" }
                                )
                                InfoSection(
                                    "灵魂",
                                    buildString {
                                        appendLine("Personality: ${agent.soul.personality.ifBlank { "未形成" }}")
                                        appendLine("Beliefs: ${agent.soul.beliefs.ifBlank { "未形成" }}")
                                        appendLine("Goals: ${agent.soul.goals.ifBlank { "未形成" }}")
                                        append("Journal: ${agent.soul.journal.ifBlank { "暂无" }}")
                                    }
                                )
                            }
                            else -> {
                                InfoSection(
                                    "Stars 流水",
                                    if (agent.starTransactions.isEmpty()) "暂无"
                                    else agent.starTransactions.takeLast(20).joinToString("\n") {
                                        val sign = if (it.amount > 0) "+" else ""
                                        "• ${sign}${it.amount}⭐  ${it.reason}  余额 ${it.balance}"
                                    }
                                )
                                InfoSection(
                                    "武器库存",
                                    buildString {
                                        appendLine("默认武器: fist, pistol")
                                        if (agent.weaponAmmo.isEmpty()) {
                                            append("暂无额外弹药")
                                        } else {
                                            agent.weaponAmmo.entries.sortedBy { it.key }.forEach { (key, ammo) ->
                                                appendLine("$key × $ammo")
                                            }
                                        }
                                    }
                                )
                                InfoSection(
                                    "系统状态",
                                    buildString {
                                        appendLine("复活卡: ${agent.revivalCards}")
                                        appendLine("思考轮次: ${agent.thinkCycleCount}")
                                        appendLine("累计 Tokens: ${agent.totalTokensUsed}")
                                        appendLine("失败次数: ${agent.consecutiveFailures}")
                                        append("待回复主人数: ${agent.pendingOwnerReplies}")
                                    }
                                )
                            }
                        }
                    }
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF2D2014))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(2.dp)
                        .background(Color(0xFF6A4D2D))
                )
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    OutlinedTextField(
                        value = input,
                        onValueChange = { input = it },
                        modifier = Modifier.weight(1f),
                        minLines = 1,
                        maxLines = 3,
                        label = { Text("给主人发消息") },
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedContainerColor = Color(0xFF1B140F),
                            unfocusedContainerColor = Color(0xFF1B140F),
                            focusedBorderColor = Color(0xFFE0B85F),
                            unfocusedBorderColor = Color(0xFF6A4D2D),
                            focusedLabelColor = Color(0xFFE0B85F),
                            unfocusedLabelColor = Color(0xFFB89D7B),
                            cursorColor = Color(0xFFE0B85F),
                            focusedTextColor = Color(0xFFF0E7D1),
                            unfocusedTextColor = Color(0xFFF0E7D1),
                        ),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                        keyboardActions = KeyboardActions(
                            onSend = {
                                val text = input.trim()
                                if (text.isNotBlank()) {
                                    engine.sendOwnerMessage(agent.entityID, text)
                                    input = ""
                                }
                            }
                        ),
                    )
                    Button(
                        onClick = {
                            val text = input.trim()
                            if (text.isNotBlank()) {
                                engine.sendOwnerMessage(agent.entityID, text)
                                input = ""
                            }
                        },
                        modifier = Modifier.height(56.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFF5C442D),
                            contentColor = Color(0xFFF1E2B7),
                        ),
                        shape = RoundedCornerShape(10.dp),
                    ) {
                        Text("发送")
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsOverlay(
    engine: StarsEngine,
    modifier: Modifier = Modifier,
) {
    var tab by remember { mutableIntStateOf(0) }
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()

    Box(
        modifier = modifier
            .background(Color(0xAA05070F))
            .padding(20.dp),
        contentAlignment = Alignment.Center,
    ) {
        ElevatedCard(
            modifier = Modifier
                .fillMaxWidth(0.88f)
                .fillMaxHeight(0.92f),
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.elevatedCardColors(containerColor = Color(0xF4161720)),
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xFF20180F))
                        .padding(horizontal = 18.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("设置", style = MaterialTheme.typography.displayMedium)
                        Text("模型、规则、经济、音频与说明", style = MaterialTheme.typography.bodySmall, color = Color(0xFFBBAE95))
                    }
                    TextButton(onClick = { engine.toggleSettings() }) {
                        Text("关闭")
                    }
                }

                TabRow(selectedTabIndex = tab) {
                    listOf("模型", "规则", "经济音频", "说明").forEachIndexed { index, label ->
                        Tab(
                            selected = tab == index,
                            onClick = { tab = index },
                            text = { Text(label) },
                        )
                    }
                }

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(scroll)
                        .padding(horizontal = 18.dp, vertical = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    when (tab) {
                        0 -> ModelSettingsTab(engine)
                        1 -> RulesSettingsTab(engine)
                        2 -> EconomyAudioTab(engine)
                        else -> AboutSettingsTab(engine)
                    }
                }
            }
        }
    }
}

@Composable
private fun ModelSettingsTab(engine: StarsEngine) {
    InfoSection(
        title = "模型说明",
        body = "每个模型都会在世界中生成一个独立 Agent。Android 端保留了原项目的 OpenAI-compatible / Anthropic-compatible 协议调用方式，以及同样的自由行动逻辑。",
    )

    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedButton(
            onClick = { engine.saveModel(engine.createBlankModel(APIProvider.OpenAI)) }
        ) {
            Text("新增 OpenAI Agent")
        }
        OutlinedButton(
            onClick = { engine.saveModel(engine.createBlankModel(APIProvider.Anthropic)) }
        ) {
            Text("新增 Anthropic Agent")
        }
    }

    Text(
        "内置向导“星尘”始终存在，不在这里编辑。",
        style = MaterialTheme.typography.bodySmall,
        color = Color(0xFFFFA76B),
    )

    engine.modelConfigs.forEach { config ->
        ModelEditorCard(
            model = config,
            onSave = engine::saveModel,
            onDelete = { engine.deleteModel(config.id) },
        )
    }
}

@Composable
private fun ModelEditorCard(
    model: ModelConfig,
    onSave: (ModelConfig) -> Unit,
    onDelete: () -> Unit,
) {
    var alias by remember(model) { mutableStateOf(model.alias) }
    var provider by remember(model) { mutableStateOf(model.provider) }
    var baseUrl by remember(model) { mutableStateOf(model.baseUrl) }
    var modelName by remember(model) { mutableStateOf(model.modelName) }
    var apiKey by remember(model) { mutableStateOf(model.apiKey) }
    var providerMenuExpanded by remember(model.id) { mutableStateOf(false) }

    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = Color(0xFF1A1D29)),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(alias.ifBlank { "未命名 Agent" }, style = MaterialTheme.typography.titleLarge)
                    Text(
                        "状态 ${connectionLabel(model.connectionStatus)}",
                        color = connectionColor(model.connectionStatus),
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
                TextButton(onClick = onDelete) {
                    Text("删除")
                }
            }

            OutlinedTextField(
                value = alias,
                onValueChange = { alias = it },
                label = { Text("Agent 名称") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )

            Box {
                OutlinedButton(onClick = { providerMenuExpanded = true }) {
                    Text("Provider: ${provider.displayName}")
                }
                DropdownMenu(
                    expanded = providerMenuExpanded,
                    onDismissRequest = { providerMenuExpanded = false },
                ) {
                    APIProvider.entries.forEach { candidate ->
                        DropdownMenuItem(
                            text = { Text(candidate.displayName) },
                            onClick = {
                                provider = candidate
                                if (baseUrl.isBlank()) {
                                    baseUrl = candidate.defaultBaseUrl
                                }
                                if (modelName.isBlank()) {
                                    modelName = candidate.defaultModel
                                }
                                providerMenuExpanded = false
                            },
                        )
                    }
                }
            }

            OutlinedTextField(
                value = baseUrl,
                onValueChange = { baseUrl = it },
                label = { Text("Base URL") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            OutlinedTextField(
                value = modelName,
                onValueChange = { modelName = it },
                label = { Text("Model Name") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            OutlinedTextField(
                value = apiKey,
                onValueChange = { apiKey = it },
                label = { Text("API Key") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 2,
                maxLines = 3,
            )

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = {
                        onSave(
                            model.copy(
                                alias = alias.trim().ifBlank { model.alias },
                                provider = provider,
                                baseUrl = baseUrl.trim(),
                                modelName = modelName.trim().ifBlank { provider.defaultModel },
                                apiKey = apiKey.trim(),
                            )
                        )
                    }
                ) {
                    Text("保存")
                }
                Text(
                    "世界里会实时同步同名 Agent。",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF98A2B3),
                    modifier = Modifier.align(Alignment.CenterVertically),
                )
            }
        }
    }
}

@Composable
private fun RulesSettingsTab(engine: StarsEngine) {
    var constitution by remember(engine.constitution) { mutableStateOf(engine.constitution) }
    var commands by remember(engine.commandsText) { mutableStateOf(engine.commandsText) }

    InfoSection(
        title = "规则编辑",
        body = "这里对应 iOS 原项目里的宪法与命令说明。保存后，世界中的 Agent 会把它当成新的系统规则重新思考。",
    )

    EditableSection(
        title = "世界宪法",
        value = constitution,
        onValueChange = { constitution = it },
        onSave = { engine.updateConstitution(constitution) },
        minLines = 8,
    )

    EditableSection(
        title = "命令规则",
        value = commands,
        onValueChange = { commands = it },
        onSave = { engine.updateCommandsText(commands) },
        minLines = 10,
    )
}

@Composable
private fun EconomyAudioTab(engine: StarsEngine) {
    var economy by remember(engine.economyText) { mutableStateOf(engine.economyText) }
    var bgmMenuExpanded by remember { mutableStateOf(false) }

    EditableSection(
        title = "经济规则",
        value = economy,
        onValueChange = { economy = it },
        onSave = { engine.updateEconomyText(economy) },
        minLines = 12,
    )

    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = Color(0xFF1A1D29)),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text("音频", style = MaterialTheme.typography.titleLarge)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("BGM 音量 ${"%.2f".format(engine.bgmVolume)}", style = MaterialTheme.typography.bodyMedium)
                Slider(value = engine.bgmVolume, onValueChange = engine::updateBgmVolume)
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("SFX 音量 ${"%.2f".format(engine.sfxVolume)}", style = MaterialTheme.typography.bodyMedium)
                Slider(value = engine.sfxVolume, onValueChange = engine::updateSfxVolume)
            }
            Box {
                OutlinedButton(onClick = { bgmMenuExpanded = true }) {
                    Text("BGM 来源: ${engine.bgmSource.name}")
                }
                DropdownMenu(
                    expanded = bgmMenuExpanded,
                    onDismissRequest = { bgmMenuExpanded = false },
                ) {
                    BgmSource.entries.forEach { source ->
                        DropdownMenuItem(
                            text = { Text(source.name) },
                            onClick = {
                                engine.updateBgmSource(source)
                                bgmMenuExpanded = false
                            },
                        )
                    }
                }
            }
        }
    }

    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = Color(0xFF1A1D29)),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("世界状态", style = MaterialTheme.typography.titleLarge)
            Text("天气: ${weatherLabel(engine.weatherEffect)}", style = MaterialTheme.typography.bodyMedium)
            Text("待处理交易: ${engine.pendingTrades.size}", style = MaterialTheme.typography.bodyMedium)
            Text("公开悬赏: ${engine.bounties.size}", style = MaterialTheme.typography.bodyMedium)
            Text("现存建筑: ${engine.structures.size}", style = MaterialTheme.typography.bodyMedium)
            Text("弹体数: ${engine.projectiles.size}", style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun AboutSettingsTab(engine: StarsEngine) {
    InfoSection("关于", engine.aboutText)
    InfoSection(
        "Android 复刻说明",
        buildString {
            appendLine("• 保留无限像素地图、建造、战斗、交易、悬赏、排行榜、聊天和存档。")
            appendLine("• 内置音频使用原 iOS 工程资源。")
            appendLine("• 图标使用原 iOS AppIcon 源图生成。")
            append("• Agent 仍按原项目思路走 LLM 驱动 JSON 行动协议。")
        }
    )
}

@Composable
private fun EditableSection(
    title: String,
    value: String,
    onValueChange: (String) -> Unit,
    onSave: () -> Unit,
    minLines: Int,
) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = Color(0xFF1A1D29)),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleLarge)
            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier.fillMaxWidth(),
                minLines = minLines,
                maxLines = minLines + 6,
            )
            Button(onClick = onSave) {
                Text("保存")
            }
        }
    }
}

@Composable
private fun InfoSection(
    title: String,
    body: String,
) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = Color(0xFF2B2015)),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleLarge, color = Color(0xFFE6C56B))
            Text(body, style = MaterialTheme.typography.bodyMedium, color = Color(0xFFF0E7D1))
        }
    }
}

@Composable
private fun StatPill(label: String) {
    Surface(
        shape = RoundedCornerShape(999.dp),
        color = Color(0xFF3A2A1C),
    ) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            style = MaterialTheme.typography.bodySmall,
            color = Color(0xFFF0E7D1),
        )
    }
}

@Composable
private fun RowScope.SpacerWeight() {
    Spacer(modifier = Modifier.weight(1f))
}

private fun worldToScreen(
    worldX: Float,
    worldY: Float,
    viewport: IntSize,
    engine: StarsEngine,
): Offset {
    val x = viewport.width / 2f + (worldX - engine.cameraX) / engine.cameraScale
    val y = viewport.height / 2f - (worldY - engine.cameraY) / engine.cameraScale
    return Offset(x, y)
}

private fun screenToWorld(
    screen: Offset,
    viewport: IntSize,
    engine: StarsEngine,
): Offset {
    val worldX = engine.cameraX + (screen.x - viewport.width / 2f) * engine.cameraScale
    val worldY = engine.cameraY - (screen.y - viewport.height / 2f) * engine.cameraScale
    return Offset(worldX, worldY)
}

private fun focusAgent(engine: StarsEngine, agent: AgentEntity) {
    engine.focusAgent(agent)
}

private fun focusAgent(engine: StarsEngine, agent: AgentEntity, cameraOffsetX: Float) {
    engine.focusAgent(agent, cameraOffsetX)
}

private fun weatherLabel(effect: WeatherEffect): String {
    return when (effect) {
        WeatherEffect.Clear -> "晴朗"
        WeatherEffect.Rain -> "小雨"
        WeatherEffect.HeavyRain -> "暴雨"
        WeatherEffect.Snow -> "下雪"
        WeatherEffect.Thunderstorm -> "雷暴"
        WeatherEffect.Fog -> "雾"
    }
}

private fun weatherTint(effect: WeatherEffect): Color {
    return when (effect) {
        WeatherEffect.Clear -> Color(0xFFE8C96B)
        WeatherEffect.Rain -> Color(0xFF8CB8DC)
        WeatherEffect.HeavyRain -> Color(0xFF6EA7D3)
        WeatherEffect.Snow -> Color(0xFFE6EFFB)
        WeatherEffect.Thunderstorm -> Color(0xFFFFB36A)
        WeatherEffect.Fog -> Color(0xFFD8E3E8)
    }
}

private fun actionLabel(action: AgentActionType): String {
    return when (action) {
        AgentActionType.Idle -> "待机"
        AgentActionType.Move -> "移动"
        AgentActionType.Build -> "建造"
        AgentActionType.Attack -> "战斗"
        AgentActionType.Talk -> "交谈"
    }
}

private fun connectionLabel(status: ConnectionStatus): String {
    return when (status) {
        ConnectionStatus.Unknown -> "未测试"
        ConnectionStatus.Success -> "连接成功"
        ConnectionStatus.Failure -> "连接失败"
        ConnectionStatus.Paused -> "已暂停"
    }
}

private fun connectionColor(status: ConnectionStatus): Color {
    return when (status) {
        ConnectionStatus.Unknown -> Color(0xFFE4C25E)
        ConnectionStatus.Success -> Color(0xFF8FD887)
        ConnectionStatus.Failure -> Color(0xFFFF8671)
        ConnectionStatus.Paused -> Color(0xFF8F9DB1)
    }
}
