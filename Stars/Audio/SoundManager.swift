//
//  SoundManager.swift
//  Stars
//
//  Centralized audio system — BGM loop + weapon SFX.
//  BGM cycles through 3 songs in order; SFX mapped to weapon categories.
//  Volume settings persist via UserDefaults.
//

import AVFoundation

@MainActor
final class SoundManager {

    static let shared = SoundManager()

    // MARK: - BGM Source

    enum BGMSource: String {
        case builtIn     = "builtIn"
        case appleMusic  = "appleMusic"
    }

    private let bgmSourceKey = "stars.sound.bgmSource"

    var bgmSource: BGMSource {
        didSet {
            UserDefaults.standard.set(bgmSource.rawValue, forKey: bgmSourceKey)
        }
    }

    /// Switch BGM source: stops current playback, starts the new source.
    func switchBGMSource(_ source: BGMSource) {
        guard source != bgmSource else { return }

        // Stop whatever is currently playing
        stopBGM()
        AppleMusicManager.shared.stopPlayback()

        bgmSource = source

        // Start the new source
        if source == .appleMusic {
            Task { await AppleMusicManager.shared.startPlayback() }
        } else {
            startBGM()
        }
    }

    // MARK: - BGM

    private var bgmPlayer: AVAudioPlayer?
    private var bgmIndex: Int = 0
    private let bgmFiles: [String] = [
        "Moon and Sun",
        "Everything Moves",
        "Litae",
    ]

    // MARK: - SFX

    /// Reusable SFX players keyed by filename (preloaded).
    private var sfxPlayers: [String: AVAudioPlayer] = [:]

    /// Maps weaponID → SFX filename (without extension).
    private let weaponSFXMap: [String: String] = [
        // Bullet-type weapons → gunshot
        "pistol":          "枪声",
        "rifle":           "枪声",
        "shotgun":         "枪声",
        "smg":             "枪声",
        "sniper":          "枪声",
        "crossbow":        "枪声",

        // Laser
        "laser":           "激光",
        "flamethrower":    "激光",
        "poison_dart":     "激光",

        // Explosive projectile
        "rocket_launcher": "火箭弹",
        "grenade":         "火箭弹",
        "mortar":          "火箭弹",
        "plasma_cannon":   "火箭弹",

        // Missile (homing)
        "missile":         "导弹",
        "drone_strike":    "导弹",

        // Mine / AoE melee
        "landmine":        "地雷",
        "claymore":        "地雷",
    ]

    // MARK: - Volume

    private let bgmVolumeKey = "stars.sound.bgmVolume"
    private let sfxVolumeKey = "stars.sound.sfxVolume"

    var bgmVolume: Float {
        didSet {
            bgmVolume = max(0, min(1, bgmVolume))
            bgmPlayer?.volume = bgmVolume
            UserDefaults.standard.set(bgmVolume, forKey: bgmVolumeKey)
        }
    }

    var sfxVolume: Float {
        didSet {
            sfxVolume = max(0, min(1, sfxVolume))
            UserDefaults.standard.set(sfxVolume, forKey: sfxVolumeKey)
        }
    }

    // MARK: - Init

    private init() {
        // Load persisted volumes (default: BGM 10%, SFX 40%)
        let savedBGM = UserDefaults.standard.object(forKey: bgmVolumeKey)
        bgmVolume = (savedBGM as? Float) ?? 0.1

        let savedSFX = UserDefaults.standard.object(forKey: sfxVolumeKey)
        sfxVolume = (savedSFX as? Float) ?? 0.4

        // Load persisted BGM source
        if let raw = UserDefaults.standard.string(forKey: bgmSourceKey),
           let src = BGMSource(rawValue: raw) {
            bgmSource = src
        } else {
            bgmSource = .builtIn
        }

        // Configure audio session
        configureAudioSession()
        preloadSFX()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[SoundManager] Audio session error: \(error)")
        }
    }

    // MARK: - BGM Playback

    func startBGM() {
        if bgmSource == .appleMusic {
            Task { await AppleMusicManager.shared.startPlayback() }
            return
        }
        guard bgmPlayer == nil || bgmPlayer?.isPlaying != true else { return }
        playBGMTrack(at: bgmIndex)
    }

    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }

    func pauseBGM() {
        bgmPlayer?.pause()
    }

    func resumeBGM() {
        bgmPlayer?.play()
    }

    private func playBGMTrack(at index: Int) {
        guard !bgmFiles.isEmpty else { return }
        let safeIndex = index % bgmFiles.count
        bgmIndex = safeIndex
        let name = bgmFiles[safeIndex]

        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "Music/BGM") else {
            // Try without subdirectory (flat bundle)
            guard let url2 = Bundle.main.url(forResource: name, withExtension: "mp3") else {
                print("[SoundManager] BGM not found: \(name).mp3")
                advanceBGM()
                return
            }
            startBGMPlayer(url: url2)
            return
        }
        startBGMPlayer(url: url)
    }

    private func startBGMPlayer(url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = bgmVolume
            player.numberOfLoops = 0  // Play once, then advance
            player.delegate = bgmDelegate
            player.prepareToPlay()
            player.play()
            bgmPlayer = player
        } catch {
            print("[SoundManager] BGM play error: \(error)")
            advanceBGM()
        }
    }

    fileprivate func advanceBGM() {
        bgmIndex = (bgmIndex + 1) % max(1, bgmFiles.count)
        // Small delay before next track
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.playBGMTrack(at: self?.bgmIndex ?? 0)
        }
    }

    /// Delegate object to handle track-end → advance to next song.
    private lazy var bgmDelegate: BGMDelegate = BGMDelegate(manager: self)

    // MARK: - SFX

    private func preloadSFX() {
        let uniqueFiles = Set(weaponSFXMap.values)
        for name in uniqueFiles {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "Music/Dota")
                ?? Bundle.main.url(forResource: name, withExtension: "mp3") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    sfxPlayers[name] = player
                } catch {
                    print("[SoundManager] SFX preload error (\(name)): \(error)")
                }
            } else {
                print("[SoundManager] SFX not found: \(name).mp3")
            }
        }
    }

    /// Play the SFX for a weapon. Called from weapon attack code.
    func playWeaponSFX(weaponID: String) {
        guard sfxVolume > 0 else { return }
        guard let sfxName = weaponSFXMap[weaponID] else { return }

        // Try to reuse preloaded player; if busy, create new instance
        if let player = sfxPlayers[sfxName] {
            if player.isPlaying {
                // Clone for overlapping sounds
                guard let url = Bundle.main.url(forResource: sfxName, withExtension: "mp3", subdirectory: "Music/Dota")
                    ?? Bundle.main.url(forResource: sfxName, withExtension: "mp3"),
                      let clone = try? AVAudioPlayer(contentsOf: url) else { return }
                clone.volume = sfxVolume
                clone.play()
                return
            }
            player.volume = sfxVolume
            player.currentTime = 0
            player.play()
        }
    }
}

// MARK: - BGM Delegate (track-end → next song)

private final class BGMDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    private weak var manager: SoundManager?

    init(manager: SoundManager) {
        self.manager = manager
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.manager?.advanceBGM()
        }
    }
}
