//
//  WorldClock.swift
//  Stars
//
//  Tracks in-game time synced with the device's real clock.
//  Hour and minute always match device time.
//  Day counter persists across sessions (increments on real calendar day changes).
//

import SpriteKit

@MainActor
final class WorldClock {
    static let shared = WorldClock()

    // MARK: - State

    /// Number of real days elapsed since world creation.
    private(set) var daysSinceCreation: Int = 0

    /// The last calendar date the clock was running on (used to detect day rollover).
    private var lastKnownDate: Date = Date()

    private let calendar = Calendar.current

    // MARK: - Real-Time Properties

    /// Current day (1-based).
    var day: Int { daysSinceCreation + 1 }

    /// Hour of the current day (0–23), from device clock.
    var hour: Int { calendar.component(.hour, from: Date()) }

    /// Minute within the current hour (0–59), from device clock.
    var minute: Int { calendar.component(.minute, from: Date()) }

    /// Minutes elapsed in the current day (0–1439).
    var minuteOfDay: Double { Double(hour * 60 + minute) }

    /// Total minutes since world creation (for persistence compatibility).
    var totalMinutes: Double {
        Double(daysSinceCreation * 1440 + hour * 60 + minute)
    }

    // MARK: - Formatted Strings

    /// "Day 3, 14:05"
    var displayText: String {
        String(format: "Day %d, %02d:%02d", day, hour, minute)
    }

    /// "14:05" for prompt injection.
    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Descriptive period name for the prompt.
    var periodName: String {
        switch hour {
        case 5..<7:   return "dawn"
        case 7..<12:  return "morning"
        case 12..<14: return "midday"
        case 14..<17: return "afternoon"
        case 17..<19: return "dusk"
        case 19..<22: return "night"
        default:       return "deep night"
        }
    }

    /// True during night hours (19:00–05:00).
    var isNight: Bool {
        hour >= 19 || hour < 5
    }

    /// One-line time context for agent prompts.
    var promptContext: String {
        "Current time: \(timeText) (\(periodName)), Day \(day)."
    }

    // MARK: - Day/Night Tint

    /// Returns a tint color and alpha to overlay the scene for day/night.
    var ambientTint: (color: SKColor, alpha: CGFloat) {
        let m = minuteOfDay
        switch m {
        case 0..<300:
            // 00:00–05:00  deep night → dark blue tint
            return (SKColor(red: 0.08, green: 0.08, blue: 0.18, alpha: 1), 0.55)
        case 300..<420:
            // 05:00–07:00  dawn → gradual brightening
            let t = CGFloat((m - 300) / 120)  // 0→1
            let alpha = 0.55 * (1 - t)
            return (SKColor(red: 0.15, green: 0.10, blue: 0.20, alpha: 1), alpha)
        case 420..<1020:
            // 07:00–17:00  daytime → no tint
            return (SKColor.clear, 0)
        case 1020..<1140:
            // 17:00–19:00  dusk → warm orange fading to blue
            let t = CGFloat((m - 1020) / 120)  // 0→1
            let r = 0.25 * (1 - t) + 0.08 * t
            let g = 0.12 * (1 - t) + 0.08 * t
            let b = 0.08 * (1 - t) + 0.18 * t
            return (SKColor(red: r, green: g, blue: b, alpha: 1), 0.15 + 0.40 * t)
        default:
            // 19:00–24:00  night
            return (SKColor(red: 0.08, green: 0.08, blue: 0.18, alpha: 1), 0.55)
        }
    }

    // MARK: - Update

    /// Called every frame to check for calendar day rollover.
    func update(deltaTime dt: TimeInterval) {
        let now = Date()
        if !calendar.isDate(now, inSameDayAs: lastKnownDate) {
            let dayDiff = calendar.dateComponents([.day], from: lastKnownDate, to: now).day ?? 0
            if dayDiff > 0 {
                daysSinceCreation += dayDiff
            }
            lastKnownDate = now
        }
    }

    // MARK: - Persistence

    /// Restore from saved state. Uses saved totalMinutes to reconstruct the day counter.
    /// If `savedAt` is provided, also adds any calendar days that elapsed between
    /// the save date and today (fixes the "always Day 1" bug when the app restarts
    /// across calendar day boundaries).
    func restore(totalMinutes: Double, savedAt: Date? = nil) {
        daysSinceCreation = max(0, Int(totalMinutes / 1440.0))
        if let savedAt {
            let daysPassed = calendar.dateComponents([.day], from: calendar.startOfDay(for: savedAt),
                                                      to: calendar.startOfDay(for: Date())).day ?? 0
            if daysPassed > 0 {
                daysSinceCreation += daysPassed
            }
        }
        lastKnownDate = Date()
    }
}
