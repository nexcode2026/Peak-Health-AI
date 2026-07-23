import Foundation
import SwiftData

// MARK: - Achievement / Badge

@Model
final class Achievement {
    var id: UUID
    var type: String // AchievementType raw value
    var title: String
    var detail: String
    var icon: String
    var unlockedAt: Date?
    var progress: Double // 0-1 for partial progress
    var targetValue: Double
    var currentValue: Double

    init(
        type: AchievementType,
        title: String,
        detail: String,
        icon: String,
        targetValue: Double = 1
    ) {
        self.id = UUID()
        self.type = type.rawValue
        self.title = title
        self.detail = detail
        self.icon = icon
        self.targetValue = targetValue
        self.currentValue = 0
        self.progress = 0
    }

    var achievementType: AchievementType {
        AchievementType(rawValue: type) ?? .firstLog
    }

    var isUnlocked: Bool { unlockedAt != nil }

    func updateProgress(_ value: Double) {
        currentValue = value
        progress = min(1, value / targetValue)
        if progress >= 1 && unlockedAt == nil {
            unlockedAt = Date()
        }
    }
}

enum AchievementType: String, CaseIterable, Codable {
    case firstLog = "first_log"
    case weekStreak = "week_streak"
    case monthStreak = "month_streak"
    case hydrationHero = "hydration_hero"
    case sleepChampion = "sleep_champion"
    case recoveryPeak = "recovery_peak"
    case habitMaster = "habit_master"
    case moodTracker = "mood_tracker"
    case coachConversation = "coach_conversation"

    var defaultTitle: String {
        switch self {
        case .firstLog: return "First Step"
        case .weekStreak: return "Week Warrior"
        case .monthStreak: return "Monthly Momentum"
        case .hydrationHero: return "Hydration Hero"
        case .sleepChampion: return "Sleep Champion"
        case .recoveryPeak: return "Peak Performance"
        case .habitMaster: return "Habit Master"
        case .moodTracker: return "Mindful Tracker"
        case .coachConversation: return "Coach Connected"
        }
    }

    var defaultDetail: String {
        switch self {
        case .firstLog: return "Log your first habit"
        case .weekStreak: return "7-day habit streak"
        case .monthStreak: return "30-day habit streak"
        case .hydrationHero: return "Hit water goal 7 days in a row"
        case .sleepChampion: return "8+ hours sleep for 5 nights"
        case .recoveryPeak: return "Recovery score above 85"
        case .habitMaster: return "Complete all habits for 14 days"
        case .moodTracker: return "Log mood 10 times"
        case .coachConversation: return "Have your first Coach chat"
        }
    }

    var icon: String {
        switch self {
        case .firstLog: return "flag.fill"
        case .weekStreak: return "flame.fill"
        case .monthStreak: return "star.fill"
        case .hydrationHero: return "drop.fill"
        case .sleepChampion: return "moon.stars.fill"
        case .recoveryPeak: return "mountain.2.fill"
        case .habitMaster: return "checkmark.seal.fill"
        case .moodTracker: return "heart.fill"
        case .coachConversation: return "bubble.left.and.bubble.right.fill"
        }
    }
}