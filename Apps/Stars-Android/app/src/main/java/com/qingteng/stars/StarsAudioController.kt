package com.qingteng.stars

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import androidx.annotation.RawRes
import kotlin.random.Random

class StarsAudioController(
    context: Context,
) {
    private val appContext = context.applicationContext
    private val bgmTracks = listOf(
        R.raw.moon_and_sun,
        R.raw.everything_moves,
        R.raw.litae,
    )
    private val soundPool = SoundPool.Builder()
        .setMaxStreams(8)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()
    private val sfx = mapOf(
        "gun" to soundPool.load(appContext, R.raw.gunshot, 1),
        "laser" to soundPool.load(appContext, R.raw.laser, 1),
        "rocket" to soundPool.load(appContext, R.raw.rocket, 1),
        "missile" to soundPool.load(appContext, R.raw.missile, 1),
        "mine" to soundPool.load(appContext, R.raw.mine, 1),
    )

    private var mediaPlayer: MediaPlayer? = null
    private var bgmVolume: Float = 0.12f
    private var sfxVolume: Float = 0.4f
    private var bgmEnabled = true
    private var currentTrack: Int? = null

    fun setBgmVolume(value: Float) {
        bgmVolume = value.coerceIn(0f, 1f)
        mediaPlayer?.setVolume(bgmVolume, bgmVolume)
    }

    fun setSfxVolume(value: Float) {
        sfxVolume = value.coerceIn(0f, 1f)
    }

    fun start(source: BgmSource) {
        bgmEnabled = source == BgmSource.BuiltIn
        if (!bgmEnabled) {
            stopBgm()
            return
        }
        if (mediaPlayer == null) {
            playNextTrack()
        } else {
            mediaPlayer?.start()
        }
    }

    fun pauseBgm() {
        mediaPlayer?.pause()
    }

    fun resumeBgm() {
        if (bgmEnabled) {
            start(BgmSource.BuiltIn)
        }
    }

    fun playWeapon(weaponId: String) {
        val key = when (weaponId) {
            "laser", "plasma_cannon" -> "laser"
            "rocket_launcher", "mortar" -> "rocket"
            "missile", "drone_strike" -> "missile"
            "grenade", "landmine", "claymore" -> "mine"
            "pistol", "rifle", "shotgun", "smg", "sniper", "crossbow", "poison_dart", "flamethrower" -> "gun"
            else -> null
        } ?: return
        soundPool.play(sfx.getValue(key), sfxVolume, sfxVolume, 1, 0, 1f)
    }

    fun release() {
        stopBgm()
        soundPool.release()
    }

    private fun stopBgm() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
    }

    private fun playNextTrack() {
        val nextTrack = pickNextTrack()
        stopBgm()
        mediaPlayer = MediaPlayer.create(appContext, nextTrack)?.apply {
            isLooping = false
            setVolume(bgmVolume, bgmVolume)
            setOnCompletionListener { playNextTrack() }
            start()
        }
        currentTrack = nextTrack
    }

    @RawRes
    private fun pickNextTrack(): Int {
        val candidates = bgmTracks.filterNot { it == currentTrack }
        return candidates.randomOrNull(Random(System.currentTimeMillis())) ?: bgmTracks.first()
    }
}
