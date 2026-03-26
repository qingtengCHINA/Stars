package com.qingteng.stars

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.withTransform
import kotlin.math.abs
import kotlin.math.sin

private const val CreatureWidth = 16
private const val CreatureHeight = 16
private const val CreatureHalfWidth = CreatureWidth / 2
private const val CreatureLegStart = 12

private val creatureZoneProb = arrayOf(
    doubleArrayOf(0.00, 0.00, 0.00, 0.05, 0.20, 0.25, 0.10, 0.00),
    doubleArrayOf(0.00, 0.00, 0.15, 0.50, 0.75, 0.82, 0.55, 0.12),
    doubleArrayOf(0.00, 0.05, 0.35, 0.78, 0.92, 0.95, 0.82, 0.28),
    doubleArrayOf(0.00, 0.10, 0.52, 0.88, 0.96, 0.98, 0.90, 0.38),
    doubleArrayOf(0.00, 0.10, 0.52, 0.88, 0.96, 0.98, 0.90, 0.38),
    doubleArrayOf(0.00, 0.08, 0.45, 0.82, 0.94, 0.96, 0.85, 0.32),
    doubleArrayOf(0.00, 0.05, 0.30, 0.68, 0.85, 0.90, 0.75, 0.22),
    doubleArrayOf(0.00, 0.00, 0.15, 0.45, 0.68, 0.75, 0.58, 0.12),
    doubleArrayOf(0.00, 0.10, 0.38, 0.65, 0.88, 0.92, 0.85, 0.38),
    doubleArrayOf(0.05, 0.22, 0.52, 0.75, 0.92, 0.96, 0.92, 0.48),
    doubleArrayOf(0.05, 0.20, 0.50, 0.72, 0.92, 0.96, 0.90, 0.45),
    doubleArrayOf(0.00, 0.12, 0.38, 0.58, 0.82, 0.88, 0.78, 0.32),
    doubleArrayOf(0.00, 0.00, 0.20, 0.42, 0.62, 0.55, 0.50, 0.18),
    doubleArrayOf(0.00, 0.00, 0.12, 0.35, 0.55, 0.28, 0.48, 0.12),
    doubleArrayOf(0.00, 0.00, 0.08, 0.28, 0.48, 0.20, 0.42, 0.08),
    doubleArrayOf(0.00, 0.00, 0.00, 0.22, 0.42, 0.15, 0.35, 0.00),
)

internal data class CreatureMotion(
    val bobY: Float,
    val scaleY: Float,
    val frameIndex: Int,
)

private data class PixelCell(
    val x: Int,
    val y: Int,
    val color: Color,
)

private data class PixelFrame(
    val outline: List<PixelCell>,
    val body: List<PixelCell>,
    val eyes: List<PixelCell>,
)

private data class PixelCreatureFrames(
    val idle: PixelFrame,
    val walkLeft: PixelFrame,
    val walkRight: PixelFrame,
)

private val creatureFrameCache = mutableMapOf<String, PixelCreatureFrames>()

internal fun creatureMotion(
    seed: String,
    spriteSize: Float,
    isMoving: Boolean,
): CreatureMotion {
    val phase = creaturePhase(seed)
    val seconds = System.currentTimeMillis() / 1000f
    return if (isMoving) {
        val walkStep = seconds * 8f + phase
        CreatureMotion(
            bobY = abs(sin(walkStep.toDouble())).toFloat() * spriteSize * 0.05f,
            scaleY = 1f,
            frameIndex = if (walkStep.toInt() and 1 == 0) 1 else 2,
        )
    } else {
        val idleStep = seconds * 2.2f + phase
        CreatureMotion(
            bobY = sin(idleStep.toDouble()).toFloat() * spriteSize * 0.012f,
            scaleY = 1f + sin((idleStep + 0.35f).toDouble()).toFloat() * 0.04f,
            frameIndex = 0,
        )
    }
}

internal fun DrawScope.drawPixelCreature(
    seed: String,
    baseColorArgb: Int,
    center: Offset,
    spriteSize: Float,
    alpha: Float,
    motion: CreatureMotion,
) {
    val frames = creatureFrameCache.getOrPut("$seed:$baseColorArgb") {
        createCreatureFrames(seed, Color(baseColorArgb))
    }
    val frame = when (motion.frameIndex) {
        1 -> frames.walkLeft
        2 -> frames.walkRight
        else -> frames.idle
    }
    val pixelSize = spriteSize / CreatureWidth.toFloat()

    withTransform({
        translate(
            left = center.x - spriteSize / 2f,
            top = center.y - spriteSize / 2f + motion.bobY,
        )
        if (motion.scaleY != 1f) {
            scale(
                scaleX = 1f,
                scaleY = motion.scaleY,
                pivot = Offset(spriteSize / 2f, spriteSize / 2f),
            )
        }
    }) {
        drawPixelFrame(frame, pixelSize, alpha.coerceIn(0f, 1f))
    }
}

private fun DrawScope.drawPixelFrame(
    frame: PixelFrame,
    pixelSize: Float,
    alpha: Float,
) {
    frame.outline.forEach { cell ->
        drawRect(
            color = cell.color.copy(alpha = cell.color.alpha * alpha),
            topLeft = Offset(cell.x * pixelSize, cell.y * pixelSize),
            size = androidx.compose.ui.geometry.Size(pixelSize, pixelSize),
        )
    }
    frame.body.forEach { cell ->
        drawRect(
            color = cell.color.copy(alpha = cell.color.alpha * alpha),
            topLeft = Offset(cell.x * pixelSize, cell.y * pixelSize),
            size = androidx.compose.ui.geometry.Size(pixelSize, pixelSize),
        )
    }
    frame.eyes.forEach { cell ->
        drawRect(
            color = cell.color.copy(alpha = cell.color.alpha * alpha),
            topLeft = Offset(cell.x * pixelSize, cell.y * pixelSize),
            size = androidx.compose.ui.geometry.Size(pixelSize, pixelSize),
        )
    }
}

private fun createCreatureFrames(seed: String, baseColor: Color): PixelCreatureFrames {
    var rng = PixelRng(djb2Hash(seed))
    val body = Array(CreatureHeight) { BooleanArray(CreatureWidth) }
    for (row in 0 until CreatureHeight) {
        for (col in 0 until CreatureHalfWidth) {
            val randomValue = (rng.next() % 10_000L).toDouble() / 10_000.0
            val filled = randomValue < creatureZoneProb[row][col]
            body[row][col] = filled
            body[row][CreatureWidth - 1 - col] = filled
        }
    }

    val mass = body.sumOf { row -> row.count { it } }
    if (mass < 36) {
        for (row in 2..10) {
            for (col in 4..11) {
                body[row][col] = true
            }
        }
    }

    var eyeRow = 4
    for (testRow in 1 until CreatureHeight - 4) {
        val centerFilled = (5..10).any { col -> body[testRow][col] }
        if (centerFilled) {
            eyeRow = minOf(testRow + 1, CreatureHeight - 4)
            break
        }
    }

    val lightColor = shiftColor(baseColor, 0.18f)
    val darkColor = shiftColor(baseColor, -0.18f)
    val outlineColor = shiftColor(baseColor, -0.40f)
    val colorMap = Array(CreatureHeight) { arrayOfNulls<Color>(CreatureWidth) }
    for (row in 0 until CreatureHeight) {
        for (col in 0 until CreatureWidth) {
            if (!body[row][col]) continue
            val variant = (rng.next() % 100L).toInt()
            colorMap[row][col] = when {
                variant < 18 -> lightColor
                variant < 32 -> darkColor
                else -> baseColor
            }
        }
    }

    val walkLeft = cloneMask(body)
    for (row in CreatureHeight - 1 downTo CreatureLegStart + 1) {
        for (col in 0 until CreatureHalfWidth) {
            walkLeft[row][col] = body[row - 1][col]
        }
    }
    for (col in 0 until CreatureHalfWidth) {
        walkLeft[CreatureLegStart][col] = false
    }
    for (row in CreatureLegStart until CreatureHeight - 1) {
        for (col in CreatureHalfWidth until CreatureWidth) {
            walkLeft[row][col] = body[row + 1][col]
        }
    }
    for (col in CreatureHalfWidth until CreatureWidth) {
        walkLeft[CreatureHeight - 1][col] = false
    }

    val walkRight = cloneMask(body)
    for (row in CreatureHeight - 1 downTo CreatureLegStart + 1) {
        for (col in CreatureHalfWidth until CreatureWidth) {
            walkRight[row][col] = body[row - 1][col]
        }
    }
    for (col in CreatureHalfWidth until CreatureWidth) {
        walkRight[CreatureLegStart][col] = false
    }
    for (row in CreatureLegStart until CreatureHeight - 1) {
        for (col in 0 until CreatureHalfWidth) {
            walkRight[row][col] = body[row + 1][col]
        }
    }
    for (col in 0 until CreatureHalfWidth) {
        walkRight[CreatureHeight - 1][col] = false
    }

    return PixelCreatureFrames(
        idle = renderFrame(body, colorMap, baseColor, outlineColor, eyeRow),
        walkLeft = renderFrame(walkLeft, colorMap, baseColor, outlineColor, eyeRow),
        walkRight = renderFrame(walkRight, colorMap, baseColor, outlineColor, eyeRow),
    )
}

private fun renderFrame(
    mask: Array<BooleanArray>,
    colorMap: Array<Array<Color?>>,
    baseColor: Color,
    outlineColor: Color,
    eyeRow: Int,
): PixelFrame {
    val outline = mutableListOf<PixelCell>()
    val body = mutableListOf<PixelCell>()
    val eyes = mutableListOf<PixelCell>()
    val leftEyeCol = 5
    val rightEyeCol = CreatureWidth - 1 - leftEyeCol
    val neighbors = arrayOf(
        intArrayOf(-1, 0),
        intArrayOf(1, 0),
        intArrayOf(0, -1),
        intArrayOf(0, 1),
    )

    for (row in 0 until CreatureHeight) {
        for (col in 0 until CreatureWidth) {
            if (mask[row][col]) {
                body += PixelCell(col, row, colorMap[row][col] ?: baseColor)
                continue
            }
            val touchesBody = neighbors.any { delta ->
                val nr = row + delta[0]
                val nc = col + delta[1]
                nr in 0 until CreatureHeight && nc in 0 until CreatureWidth && mask[nr][nc]
            }
            if (touchesBody) {
                outline += PixelCell(col, row, outlineColor)
            }
        }
    }

    if (mask[eyeRow][leftEyeCol] && mask[eyeRow][rightEyeCol]) {
        eyes += PixelCell(leftEyeCol, eyeRow, Color.White)
        eyes += PixelCell(leftEyeCol + 1, eyeRow, Color.White)
        eyes += PixelCell(leftEyeCol, eyeRow + 1, Color.White)
        eyes += PixelCell(leftEyeCol + 1, eyeRow + 1, Color(0xFF181716))

        eyes += PixelCell(rightEyeCol - 1, eyeRow, Color.White)
        eyes += PixelCell(rightEyeCol, eyeRow, Color.White)
        eyes += PixelCell(rightEyeCol - 1, eyeRow + 1, Color(0xFF181716))
        eyes += PixelCell(rightEyeCol, eyeRow + 1, Color.White)
    }

    return PixelFrame(
        outline = outline,
        body = body,
        eyes = eyes,
    )
}

private fun cloneMask(mask: Array<BooleanArray>): Array<BooleanArray> {
    return Array(mask.size) { row -> mask[row].clone() }
}

private fun shiftColor(color: Color, delta: Float): Color {
    return Color(
        red = (color.red + delta).coerceIn(0f, 1f),
        green = (color.green + delta).coerceIn(0f, 1f),
        blue = (color.blue + delta).coerceIn(0f, 1f),
        alpha = 1f,
    )
}

private fun creaturePhase(seed: String): Float {
    val value = (djb2Hash(seed) and 1023L).toFloat() / 1023f
    return (value * (Math.PI * 2.0)).toFloat()
}

private fun djb2Hash(value: String): Long {
    var hash = 5381L
    value.forEach { char ->
        hash = hash * 33L + char.code.toLong()
    }
    return hash
}

private class PixelRng(seed: Long) {
    private var state: Long = if (seed == 0L) 1L else seed

    fun next(): Long {
        state = state * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
        return state ushr 33
    }
}
