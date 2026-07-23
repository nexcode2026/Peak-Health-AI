import Foundation
import SwiftData

@Model
final class Achievement {
    var id: UUID = UUID()
    var type: String = "firstLog"
    var title: String = ""
    var detail: String = ""
    var icon: String = ""
    var unlockedAt: Date? = nil
    var progress: Double = 0
    var targetValue: Double = 1
    var currentValue: Double = 0

    init(type: AchievementType, title: String, detail: String, icon: String, targetValue: Double = 1) {
        self.id = UUID()
        self.type = type.rawValue
        self.title = title
        self.detail = detail
        self.icon = icon
        self.targetValue = targetValue
        self.currentValue = 0
        self.progress = 0
    }

    var achievementType: AchievementType { AchievementType(rawValue: type) ?? .firstLog }
    var isUnlocked: Bool { unlockedAt != nil }

    func updateProgress(_ value: Double) {
        currentValue = value
        progress = min(1, value / targetValue)
        if progress >= 1 && unlockedAt == nil { unlockedAt = Date() }
    }
}

enum AchievementCategory: String, CaseIterable, Codable {
    case recovery, sleep, activity, nutrition, habits, mindfulness, social

    var displayName: String {
        switch self {
        case .recovery: return "Recovery"
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .nutrition: return "Nutrition"
        case .habits: return "Habits"
        case .mindfulness: return "Mindfulness"
        case .social: return "Coach"
        }
    }
}

enum AchievementTier: String, Codable {
    case bronze, silver, gold, platinum

    var displayName: String { rawValue.capitalized }
}

enum AchievementType: String, CaseIterable, Codable {
    // Original
    case firstLog, weekStreak, monthStreak, hydrationHero, sleepChampion
    case recoveryPeak, habitMaster, moodTracker, coachConversation
    case foodLogger, workoutWarrior, waterWarrior, earlyBird
    // Expanded — recovery & sleep
    case recoveryElite, perfectRecoveryWeek, sleepConsistency, deepSleepDiver, hrvImprover
    // Activity
    case steps10K, steps20K, weekendWarrior, cardioCrusher, strengthStreak
    // Nutrition & hydration
    case proteinPro, calorieTracker, hydrationStreak14, balancedPlate
    // Habits & mindfulness
    case threeDayStreak, consistencyKing, mindfulWeek, journaler, zenMaster
    // Milestones
    case peakMonth, centuryClub, dataDriven

    var category: AchievementCategory {
        switch self {
        case .firstLog, .recoveryPeak, .recoveryElite, .perfectRecoveryWeek, .hrvImprover, .dataDriven:
            return .recovery
        case .sleepChampion, .sleepConsistency, .deepSleepDiver:
            return .sleep
        case .workoutWarrior, .weekendWarrior, .steps10K, .steps20K, .cardioCrusher, .strengthStreak:
            return .activity
        case .foodLogger, .proteinPro, .calorieTracker, .balancedPlate, .hydrationHero, .waterWarrior, .hydrationStreak14:
            return .nutrition
        case .weekStreak, .monthStreak, .habitMaster, .earlyBird, .threeDayStreak, .consistencyKing, .peakMonth, .centuryClub:
            return .habits
        case .moodTracker, .mindfulWeek, .journaler, .zenMaster:
            return .mindfulness
        case .coachConversation:
            return .social
        }
    }

    var tier: AchievementTier {
        switch self {
        case .firstLog, .threeDayStreak, .waterWarrior, .moodTracker:
            return .bronze
        case .weekStreak, .hydrationHero, .foodLogger, .steps10K, .journaler, .calorieTracker:
            return .silver
        case .monthStreak, .habitMaster, .sleepChampion, .workoutWarrior, .recoveryPeak, .mindfulWeek, .proteinPro:
            return .gold
        case .recoveryElite, .perfectRecoveryWeek, .peakMonth, .centuryClub, .steps20K, .hydrationStreak14, .zenMaster:
            return .platinum
        default:
            return .silver
        }
    }

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
        case .foodLogger: return "Fuel Master"
        case .workoutWarrior: return "Workout Warrior"
        case .waterWarrior: return "Water Warrior"
        case .earlyBird: return "Early Bird"
        case .recoveryElite: return "Recovery Elite"
        case .perfectRecoveryWeek: return "Perfect Week"
        case .sleepConsistency: return "Sleep Steady"
        case .deepSleepDiver: return "Deep Diver"
        case .hrvImprover: return "HRV Climber"
        case .steps10K: return "10K Strider"
        case .steps20K: return "20K Crusher"
        case .weekendWarrior: return "Weekend Warrior"
        case .cardioCrusher: return "Cardio Crusher"
        case .strengthStreak: return "Iron Streak"
        case .proteinPro: return "Protein Pro"
        case .calorieTracker: return "Macro Tracker"
        case .hydrationStreak14: return "Aqua Legend"
        case .balancedPlate: return "Balanced Plate"
        case .threeDayStreak: return "Momentum"
        case .consistencyKing: return "Consistency King"
        case .mindfulWeek: return "Mindful Week"
        case .journaler: return "Journaler"
        case .zenMaster: return "Zen Master"
        case .peakMonth: return "Peak Month"
        case .centuryClub: return "Century Club"
        case .dataDriven: return "Data Driven"
        }
    }

    var defaultDetail: String {
        switch self {
        case .firstLog: return "Log your first entry"
        case .weekStreak: return "7-day habit streak"
        case .monthStreak: return "30-day habit streak"
        case .hydrationHero: return "7 days hitting water goal"
        case .sleepChampion: return "5 nights of 8+ hours sleep"
        case .recoveryPeak: return "Recovery score above 85"
        case .habitMaster: return "14-day habit streak"
        case .moodTracker: return "Log mood 10 times"
        case .coachConversation: return "First Coach conversation"
        case .foodLogger: return "Log 10 meals"
        case .workoutWarrior: return "4 workouts in one week"
        case .waterWarrior: return "Log water 20 times"
        case .earlyBird: return "Complete 10 morning habits"
        case .recoveryElite: return "Recovery score above 90"
        case .perfectRecoveryWeek: return "7 days with recovery ≥ 75"
        case .sleepConsistency: return "14 nights with 7+ hours sleep"
        case .deepSleepDiver: return "5 nights with 60+ min deep sleep"
        case .hrvImprover: return "HRV trend up 10% over 7 days"
        case .steps10K: return "Hit 10,000 steps in a day"
        case .steps20K: return "Hit 20,000 steps in a day"
        case .weekendWarrior: return "2 workouts on a weekend"
        case .cardioCrusher: return "150+ active minutes in a week"
        case .strengthStreak: return "3 strength workouts in 7 days"
        case .proteinPro: return "Hit protein goal 7 days"
        case .calorieTracker: return "Log meals 14 days in a row"
        case .hydrationStreak14: return "14 days hitting water goal"
        case .balancedPlate: return "Log breakfast, lunch, and dinner in one day"
        case .threeDayStreak: return "3-day habit streak"
        case .consistencyKing: return "Log something 30 days in a row"
        case .mindfulWeek: return "Log mood 7 days in a row"
        case .journaler: return "Write 10 journal entries"
        case .zenMaster: return "Log mood 30 times"
        case .peakMonth: return "30-day habit streak"
        case .centuryClub: return "100 total habit completions"
        case .dataDriven: return "14 days with a recovery score"
        }
    }

    var icon: String {
        switch self {
        case .firstLog: return "flag.fill"
        case .weekStreak, .threeDayStreak, .strengthStreak: return "flame.fill"
        case .monthStreak, .peakMonth, .centuryClub: return "star.fill"
        case .hydrationHero, .waterWarrior, .hydrationStreak14: return "drop.fill"
        case .sleepChampion, .sleepConsistency, .deepSleepDiver: return "moon.stars.fill"
        case .recoveryPeak, .recoveryElite, .perfectRecoveryWeek, .dataDriven: return "mountain.2.fill"
        case .habitMaster, .consistencyKing, .earlyBird: return "checkmark.seal.fill"
        case .moodTracker, .mindfulWeek, .zenMaster: return "heart.fill"
        case .coachConversation: return "bubble.left.and.bubble.right.fill"
        case .foodLogger, .balancedPlate, .calorieTracker: return "fork.knife"
        case .workoutWarrior, .weekendWarrior, .cardioCrusher: return "figure.run"
        case .steps10K, .steps20K: return "figure.walk"
        case .proteinPro: return "bolt.fill"
        case .hrvImprover: return "waveform.path.ecg"
        case .journaler: return "book.fill"
        }
    }

    var defaultTarget: Double {
        switch self {
        case .firstLog, .recoveryPeak, .recoveryElite, .coachConversation, .steps10K, .steps20K, .balancedPlate, .hrvImprover:
            return 1
        case .weekStreak, .mindfulWeek, .perfectRecoveryWeek, .threeDayStreak:
            return 7
        case .monthStreak, .peakMonth:
            return 30
        case .habitMaster, .calorieTracker, .hydrationStreak14, .sleepConsistency:
            return 14
        case .hydrationHero: return 7
        case .sleepChampion, .deepSleepDiver: return 5
        case .moodTracker: return 10
        case .foodLogger, .journaler: return 10
        case .workoutWarrior, .strengthStreak: return 3
        case .waterWarrior: return 20
        case .earlyBird: return 10
        case .weekendWarrior, .cardioCrusher: return 2
        case .proteinPro: return 7
        case .consistencyKing, .zenMaster: return 30
        case .centuryClub: return 100
        case .dataDriven: return 14
        }
    }

    var badgeColor: String {
        switch tier {
        case .bronze: return "CD7F32"
        case .silver: return "B0BEC5"
        case .gold: return "F5A623"
        case .platinum: return "A29BFE"
        }
    }
}
