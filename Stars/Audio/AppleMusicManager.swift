//
//  AppleMusicManager.swift
//  Stars
//
//  MusicKit integration — lets users pick Apple Music library songs as BGM.
//  Singleton, @MainActor, works alongside SoundManager.
//

import Foundation
import MusicKit

@MainActor
final class AppleMusicManager {

    static let shared = AppleMusicManager()

    // MARK: - Types

    enum AuthStatus { case notDetermined, authorized, denied }

    // MARK: - Published State

    private(set) var authStatus: AuthStatus = .notDetermined
    private(set) var librarySongs: [Song] = []
    private(set) var selectedSongIDs: [MusicItemID] = []
    private(set) var isPlaying = false
    private(set) var currentSongTitle: String?

    // MARK: - Private

    private let player = ApplicationMusicPlayer.shared
    private let selectedKey = "stars.appleMusic.selectedIDs"

    // MARK: - Init

    private init() {
        // Restore persisted song IDs
        if let raw = UserDefaults.standard.stringArray(forKey: selectedKey) {
            selectedSongIDs = raw.map { MusicItemID($0) }
        }
        // Sync initial auth status
        switch MusicAuthorization.currentStatus {
        case .authorized:   authStatus = .authorized
        case .denied,
             .restricted:   authStatus = .denied
        default:            authStatus = .notDetermined
        }
    }

    // MARK: - Authorization

    @discardableResult
    func requestAuthorization() async -> AuthStatus {
        let status = await MusicAuthorization.request()
        switch status {
        case .authorized:   authStatus = .authorized
        case .denied,
             .restricted:   authStatus = .denied
        default:            authStatus = .notDetermined
        }
        return authStatus
    }

    // MARK: - Library

    func loadLibrary() async {
        guard authStatus == .authorized else { return }
        do {
            var request = MusicLibraryRequest<Song>()
            request.sort(by: \.title, ascending: true)
            let response = try await request.response()
            librarySongs = Array(response.items)
        } catch {
            print("[AppleMusicManager] Library fetch error: \(error)")
        }
    }

    // MARK: - Playlist Selection

    func setPlaylist(_ songIDs: [MusicItemID]) {
        selectedSongIDs = songIDs
        persistSelection()
    }

    func isSelected(_ song: Song) -> Bool {
        selectedSongIDs.contains(song.id)
    }

    func toggleSong(_ song: Song) {
        if let idx = selectedSongIDs.firstIndex(of: song.id) {
            selectedSongIDs.remove(at: idx)
        } else {
            selectedSongIDs.append(song.id)
        }
        persistSelection()
    }

    private func persistSelection() {
        let raw = selectedSongIDs.map { $0.rawValue }
        UserDefaults.standard.set(raw, forKey: selectedKey)
    }

    // MARK: - Playback

    func startPlayback() async {
        guard !selectedSongIDs.isEmpty else { return }

        // Resolve selected songs from the library cache
        let songs = librarySongs.filter { selectedSongIDs.contains($0.id) }
        guard !songs.isEmpty else { return }

        // Pause built-in BGM when Apple Music takes over
        SoundManager.shared.stopBGM()

        do {
            player.queue = ApplicationMusicPlayer.Queue(for: songs)
            player.state.shuffleMode = .off
            player.state.repeatMode = .all
            try await player.play()
            isPlaying = true
            currentSongTitle = songs.first?.title
        } catch {
            print("[AppleMusicManager] Playback error: \(error)")
            isPlaying = false
            currentSongTitle = nil
        }
    }

    func stopPlayback() {
        player.stop()
        isPlaying = false
        currentSongTitle = nil
    }
}
