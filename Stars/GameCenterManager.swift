//
//  GameCenterManager.swift
//  Stars
//
//  Game Center integration — achievements and leaderboards.
//
//  Achievements:
//    The_First_Agent — First agent added
//    niubi          — 100 agents added (lifetime)
//
//  Leaderboard:
//    Model_number   — Current number of active agents
//

import GameKit

@MainActor
final class GameCenterManager {
    static let shared = GameCenterManager()

    private(set) var isAuthenticated = false

    private let leaderboardID = "Model_number"
    private let achievementFirstAgent = "The_First_Agent"
    private let achievementHundredAgents = "niubi"

    /// Total agents ever created (persisted across sessions).
    private let lifetimeAgentCountKey = "stars.lifetime.agent.count"

    private init() {}

    // MARK: - Authentication

    /// Authenticate the local player. Call once at app launch.
    func authenticate(presentingViewController: UIViewController? = nil) {
        GKLocalPlayer.local.authenticateHandler = { [weak self] loginVC, error in
            if let loginVC, let presenter = presentingViewController {
                presenter.present(loginVC, animated: true)
                return
            }

            if let error {
                print("[GameCenter] Auth error: \(error.localizedDescription)")
                self?.isAuthenticated = false
                return
            }

            self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            if GKLocalPlayer.local.isAuthenticated {
                print("[GameCenter] Authenticated as \(GKLocalPlayer.local.displayName)")
            }
        }
    }

    // MARK: - Agent Count Tracking

    /// Call when agents are synced/added. Updates leaderboard and checks achievements.
    func reportAgentCount(_ currentCount: Int) {
        guard isAuthenticated else { return }

        // Update lifetime count
        let previousLifetime = UserDefaults.standard.integer(forKey: lifetimeAgentCountKey)
        let newLifetime = max(previousLifetime, currentCount)
        UserDefaults.standard.set(newLifetime, forKey: lifetimeAgentCountKey)

        // Report leaderboard score (current active agent count)
        submitLeaderboardScore(currentCount)

        // Check achievements
        if currentCount >= 1 {
            unlockAchievement(achievementFirstAgent, percentComplete: 100)
        }
        if newLifetime >= 100 {
            unlockAchievement(achievementHundredAgents, percentComplete: 100)
        } else if newLifetime >= 1 {
            // Report incremental progress
            let progress = min(Double(newLifetime) / 100.0 * 100.0, 99.0)
            unlockAchievement(achievementHundredAgents, percentComplete: progress)
        }
    }

    // MARK: - Leaderboard

    private func submitLeaderboardScore(_ score: Int) {
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboardID]
                )
                print("[GameCenter] Leaderboard score submitted: \(score)")
            } catch {
                print("[GameCenter] Leaderboard error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Achievements

    private func unlockAchievement(_ achievementID: String, percentComplete: Double) {
        Task {
            let achievement = GKAchievement(identifier: achievementID)
            achievement.percentComplete = percentComplete
            achievement.showsCompletionBanner = true
            do {
                try await GKAchievement.report([achievement])
                if percentComplete >= 100 {
                    print("[GameCenter] Achievement unlocked: \(achievementID)")
                }
            } catch {
                print("[GameCenter] Achievement error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Dashboard

    /// Show the Game Center dashboard overlay.
    func showDashboard(from viewController: UIViewController) {
        guard isAuthenticated else { return }
        let gcVC = GKGameCenterViewController(state: .default)
        gcVC.gameCenterDelegate = viewController as? GKGameCenterControllerDelegate
        viewController.present(gcVC, animated: true)
    }
}
