import Foundation
import SwiftData

// MARK: - Achievement Unlock Engine

@MainActor
enum AchievementService {
    /// Ensures every defined badge exists in SwiftData (safe for CloudKit sync).
    static func ensureAllAchievementsExist(modelContext: ModelContext) {
        let existing = (try? modelContext.fetch(FetchDescriptor<Achievement>())) ?? []
        let existingTypes = Set(existing.map(\.type))

        for type in AchievementType.allCases {
            guard !existingTypes.contains(type.rawValue) else { continue }
            let achievement = Achievement(
                type: type,
                title: type.defaultTitle,
                detail: type.defaultDetail,
                icon: type.icon,
                targetValue: type.defaultTarget
            )
            modelContext.insert(achievement)
        }
        try? modelContext.save()
    }

    /// Recomputes progress and returns badges newly unlocked this pass.
    @discardableResult
    static func evaluateAll(modelContext: ModelContext) -> [Achievement] {
        ensureAllAchievementsExist(modelContext: modelContext)
        let achievements = (try? modelContext.fetch(FetchDescriptor<Achievement>())) ?? []
        var newlyUnlocked: [Achievement] = []

        for achievement in achievements {
            let wasUnlocked = achievement.isUnlocked
            let value = currentValue(for: achievement.achievementType, modelContext: modelContext)
            achievement.updateProgress(value)
            if !wasUnlocked && achievement.isUnlocked {
                newlyUnlocked.append(achievement)
            }
        }
        try? modelContext.save()
        return newlyUnlocked
    }

    /// Closest badges to unlocking (for dashboard nudges).
    static func nearestUnlocks(modelContext: ModelContext, limit: Int = 3) -> [Achievement] {
        let locked = (try? modelContext.fetch(FetchDescriptor<Achievement>(
            predicate: #Predicate { $0.unlockedAt == nil },
            sortBy: [SortDescriptor(\.progress, order: .reverse)]
        ))) ?? []
        return Array(locked.prefix(limit))
    }

    private static func currentValue(for type: AchievementType, modelContext: ModelContext) -> Double {
        let today = Date().startOfDay

        switch type {
        case .firstLog:
            let habits = (try? modelContext.fetch(FetchDescriptor<HabitLog>()))?.count ?? 0
            let water = (try? modelContext.fetch(FetchDescriptor<HydrationLog>()))?.count ?? 0
            return habits + water > 0 ? 1 : 0

        case .weekStreak, .monthStreak, .habitMaster, .threeDayStreak, .peakMonth:
            return Double(habitStreakDays(modelContext: modelContext))

        case .hydrationHero, .hydrationStreak14:
            return Double(consecutiveHydrationDays(modelContext: modelContext))

        case .sleepChampion:
            return Double(goodSleepNights(modelContext: modelContext, hours: 8))

        case .sleepConsistency:
            return Double(goodSleepNights(modelContext: modelContext, hours: 7))

        case .deepSleepDiver:
            return Double(deepSleepNights(modelContext: modelContext))

        case .recoveryPeak:
            return recoveryScoreMet(modelContext: modelContext, threshold: 85, todayOnly: true) ? 1 : 0

        case .recoveryElite:
            return recoveryScoreMet(modelContext: modelContext, threshold: 90, todayOnly: true) ? 1 : 0

        case .perfectRecoveryWeek:
            return Double(recoveryDaysAbove(modelContext: modelContext, threshold: 75, days: 7))

        case .dataDriven:
            return Double(recoveryScoreDays(modelContext: modelContext, days: 14))

        case .hrvImprover:
            return hrvTrendPositive(modelContext: modelContext) ? 1 : 0

        case .moodTracker, .zenMaster:
            return Double((try? modelContext.fetch(FetchDescriptor<MoodReflection>()))?.count ?? 0)

        case .mindfulWeek:
            return Double(consecutiveMoodDays(modelContext: modelContext))

        case .coachConversation:
            return Double((try? modelContext.fetch(FetchDescriptor<CoachMessage>(
                predicate: #Predicate { $0.role == "user" }
            )))?.count ?? 0)

        case .foodLogger:
            return Double((try? modelContext.fetch(FetchDescriptor<FoodLog>()))?.count ?? 0)

        case .calorieTracker:
            return Double(consecutiveFoodLogDays(modelContext: modelContext))

        case .balancedPlate:
            return balancedMealsToday(modelContext: modelContext, date: today) ? 1 : 0

        case .proteinPro:
            return Double(proteinGoalDays(modelContext: modelContext, days: 7))

        case .workoutWarrior, .strengthStreak:
            return Double(weeklyWorkoutCount(modelContext: modelContext, type: type))

        case .weekendWarrior:
            return Double(weekendWorkouts(modelContext: modelContext))

        case .cardioCrusher:
            return Double(weeklyActiveMinutes(modelContext: modelContext) >= 150 ? 1 : 0)

        case .waterWarrior:
            return Double((try? modelContext.fetch(FetchDescriptor<HydrationLog>()))?.count ?? 0)

        case .earlyBird:
            return Double(earlyHabitCompletions(modelContext: modelContext))

        case .steps10K:
            return maxStepsInDay(modelContext: modelContext) >= 10_000 ? 1 : 0

        case .steps20K:
            return maxStepsInDay(modelContext: modelContext) >= 20_000 ? 1 : 0

        case .consistencyKing:
            return Double(anyLogStreakDays(modelContext: modelContext))

        case .journaler:
            return Double((try? modelContext.fetch(FetchDescriptor<JournalEntry>()))?.count ?? 0)

        case .centuryClub:
            return Double((try? modelContext.fetch(FetchDescriptor<HabitLog>(
                predicate: #Predicate { $0.completed }
            )))?.count ?? 0)
        }
    }

    // MARK: - Metric helpers

    private static func habitStreakDays(modelContext: ModelContext) -> Int {
        var streak = 0
        for offset in 0..<60 {
            let date = Date().daysAgo(offset).startOfDay
            let logs = try? modelContext.fetch(FetchDescriptor<HabitLog>(
                predicate: #Predicate { $0.date == date && $0.completed }
            ))
            if (logs?.count ?? 0) > 0 { streak += 1 } else { break }
        }
        return streak
    }

    private static func consecutiveHydrationDays(modelContext: ModelContext) -> Int {
        guard let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first else { return 0 }
        var streak = 0
        for offset in 0..<30 {
            let start = Date().daysAgo(offset).startOfDay
            let end = start.endOfDay
            let logs = try? modelContext.fetch(FetchDescriptor<HydrationLog>(
                predicate: #Predicate { $0.date >= start && $0.date <= end }
            ))
            let total = logs?.reduce(0) { $0 + $1.amountML } ?? 0
            if total >= profile.dailyWaterGoalML { streak += 1 } else { break }
        }
        return streak
    }

    private static func goodSleepNights(modelContext: ModelContext, hours: Double) -> Int {
        let snapshots = (try? modelContext.fetch(FetchDescriptor<HealthSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )))?.prefix(30) ?? []
        return snapshots.filter { $0.sleepHours >= hours }.count
    }

    private static func deepSleepNights(modelContext: ModelContext) -> Int {
        let snapshots = (try? modelContext.fetch(FetchDescriptor<HealthSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )))?.prefix(14) ?? []
        return snapshots.filter { $0.deepSleepMinutes >= 60 }.count
    }

    private static func weeklyWorkoutCount(modelContext: ModelContext, type: AchievementType) -> Int {
        let weekAgo = Date().daysAgo(7)
        let workouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>(
            predicate: #Predicate { $0.date >= weekAgo }
        ))) ?? []
        if type == .strengthStreak {
            return workouts.filter { $0.type == .strength }.count
        }
        return workouts.count
    }

    private static func weekendWorkouts(modelContext: ModelContext) -> Int {
        let calendar = Calendar.current
        let weekAgo = Date().daysAgo(7)
        let workouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>(
            predicate: #Predicate { $0.date >= weekAgo }
        ))) ?? []
        return workouts.filter {
            let weekday = calendar.component(.weekday, from: $0.date)
            return weekday == 1 || weekday == 7
        }.count
    }

    private static func weeklyActiveMinutes(modelContext: ModelContext) -> Double {
        let weekAgo = Date().daysAgo(7)
        let snapshots = (try? modelContext.fetch(FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate { $0.date >= weekAgo }
        ))) ?? []
        return snapshots.reduce(0) { $0 + $1.workoutMinutes }
    }

    private static func earlyHabitCompletions(modelContext: ModelContext) -> Int {
        (try? modelContext.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.completed }
        )))?.count ?? 0
    }

    private static func recoveryScoreMet(modelContext: ModelContext, threshold: Int, todayOnly: Bool) -> Bool {
        if todayOnly {
            let today = Date().startOfDay
            if let score = try? modelContext.fetch(FetchDescriptor<RecoveryScore>(
                predicate: #Predicate { $0.date == today }
            )).first {
                return score.overallScore >= threshold
            }
            return false
        }
        return false
    }

    private static func recoveryDaysAbove(modelContext: ModelContext, threshold: Int, days: Int) -> Int {
        var count = 0
        for offset in 0..<days {
            let date = Date().daysAgo(offset).startOfDay
            if let score = try? modelContext.fetch(FetchDescriptor<RecoveryScore>(
                predicate: #Predicate { $0.date == date }
            )).first, score.overallScore >= threshold {
                count += 1
            }
        }
        return count
    }

    private static func recoveryScoreDays(modelContext: ModelContext, days: Int) -> Int {
        var count = 0
        for offset in 0..<days {
            let date = Date().daysAgo(offset).startOfDay
            if (try? modelContext.fetch(FetchDescriptor<RecoveryScore>(
                predicate: #Predicate { $0.date == date }
            )))?.first != nil {
                count += 1
            }
        }
        return count
    }

    private static func hrvTrendPositive(modelContext: ModelContext) -> Bool {
        let snapshots = (try? modelContext.fetch(FetchDescriptor<HealthSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )))?.prefix(8) ?? []
        guard snapshots.count >= 2 else { return false }
        let recent = snapshots.prefix(3).map(\.hrvMS).reduce(0, +) / 3
        let older = snapshots.suffix(3).map(\.hrvMS).reduce(0, +) / 3
        guard older > 0 else { return false }
        return (recent - older) / older >= 0.1
    }

    private static func consecutiveMoodDays(modelContext: ModelContext) -> Int {
        var streak = 0
        for offset in 0..<14 {
            let start = Date().daysAgo(offset).startOfDay
            let end = start.endOfDay
            let moods = try? modelContext.fetch(FetchDescriptor<MoodReflection>(
                predicate: #Predicate { $0.date >= start && $0.date <= end }
            ))
            if (moods?.count ?? 0) > 0 { streak += 1 } else { break }
        }
        return streak
    }

    private static func consecutiveFoodLogDays(modelContext: ModelContext) -> Int {
        var streak = 0
        for offset in 0..<30 {
            let start = Date().daysAgo(offset).startOfDay
            let end = start.endOfDay
            let logs = try? modelContext.fetch(FetchDescriptor<FoodLog>(
                predicate: #Predicate { $0.date >= start && $0.date <= end }
            ))
            if (logs?.count ?? 0) > 0 { streak += 1 } else { break }
        }
        return streak
    }

    private static func balancedMealsToday(modelContext: ModelContext, date: Date) -> Bool {
        let start = date.startOfDay
        let end = date.endOfDay
        let logs = (try? modelContext.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= start && $0.date <= end }
        ))) ?? []
        let meals = Set(logs.map(\.meal))
        return meals.contains(.breakfast) && meals.contains(.lunch) && meals.contains(.dinner)
    }

    private static func proteinGoalDays(modelContext: ModelContext, days: Int) -> Int {
        guard let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first else { return 0 }
        var count = 0
        for offset in 0..<days {
            let start = Date().daysAgo(offset).startOfDay
            let end = start.endOfDay
            let logs = try? modelContext.fetch(FetchDescriptor<FoodLog>(
                predicate: #Predicate { $0.date >= start && $0.date <= end }
            ))
            let protein = logs?.reduce(0.0) { $0 + $1.proteinG } ?? 0
            if protein >= Double(profile.dailyProteinGoalG) { count += 1 }
        }
        return count
    }

    private static func maxStepsInDay(modelContext: ModelContext) -> Int {
        let snapshots = (try? modelContext.fetch(FetchDescriptor<HealthSnapshot>(
            sortBy: [SortDescriptor(\.steps, order: .reverse)]
        ))) ?? []
        return snapshots.first?.steps ?? 0
    }

    private static func anyLogStreakDays(modelContext: ModelContext) -> Int {
        var streak = 0
        for offset in 0..<45 {
            let start = Date().daysAgo(offset).startOfDay
            let end = start.endOfDay
            let hasHabit = ((try? modelContext.fetch(FetchDescriptor<HabitLog>(
                predicate: #Predicate { $0.date >= start && $0.date <= end && $0.completed }
            )))?.count ?? 0) > 0
            let hasWater = ((try? modelContext.fetch(FetchDescriptor<HydrationLog>(
                predicate: #Predicate { $0.date >= start && $0.date <= end }
            )))?.count ?? 0) > 0
            let hasMood = ((try? modelContext.fetch(FetchDescriptor<MoodReflection>(
                predicate: #Predicate { $0.date >= start && $0.date <= end }
            )))?.count ?? 0) > 0
            if hasHabit || hasWater || hasMood { streak += 1 } else { break }
        }
        return streak
    }
}