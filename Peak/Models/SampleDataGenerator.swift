import Foundation
import SwiftData

// MARK: - Sample Data for Previews & Onboarding Demo

enum SampleDataGenerator {
    @MainActor
    static func populate(context: ModelContext, profile: UserProfile) {
        guard !profile.sampleDataLoaded else { return }

        // Create default habits
        for (index, habit) in PredefinedHabits.defaults.prefix(5).enumerated() {
            let definition = HabitDefinition(
                name: habit.name,
                icon: habit.icon,
                colorHex: habit.color,
                sortOrder: index
            )
            definition.owner = profile
            context.insert(definition)

            // Log habits for past 14 days
            for dayOffset in 0..<14 {
                let date = Date().daysAgo(dayOffset).startOfDay
                let completed = dayOffset < 10 || Bool.random()
                let log = HabitLog(habit: definition, date: date, completed: completed)
                context.insert(log)
            }
        }

        // Hydration logs
        for dayOffset in 0..<14 {
            let date = Date().daysAgo(dayOffset)
            let glasses = Int.random(in: 4...10)
            for _ in 0..<glasses {
                let log = HydrationLog(amountML: PeakConstants.Defaults.habitGlassML, date: date)
                context.insert(log)
            }
        }

        // Mood reflections
        for dayOffset in 0..<14 {
            let mood = MoodReflection(
                moodRating: Int.random(in: 2...5),
                energyLevel: Int.random(in: 2...5),
                note: dayOffset % 3 == 0 ? "Feeling good today." : nil,
                tags: dayOffset % 2 == 0 ? ["productive"] : ["rested"],
                date: Date().daysAgo(dayOffset)
            )
            context.insert(mood)
        }

        // Recovery scores
        for dayOffset in 0..<14 {
            let base = 65 + Int.random(in: -15...20)
            let score = RecoveryScore(
                date: Date().daysAgo(dayOffset).startOfDay,
                overallScore: base.clamped(to: 0...100),
                sleepScore: Double.random(in: 50...95),
                hrvScore: Double.random(in: 50...95),
                activityScore: Double.random(in: 50...95),
                hydrationScore: Double.random(in: 40...100),
                moodScore: Double.random(in: 50...95),
                habitScore: Double.random(in: 50...100),
                explanation: "Sample data for preview."
            )
            context.insert(score)
        }

        // Health snapshots
        for dayOffset in 0..<14 {
            let snapshot = HealthSnapshot(
                date: Date().daysAgo(dayOffset).startOfDay,
                sleepHours: Double.random(in: 6...9),
                sleepQuality: Double.random(in: 0.6...0.95),
                hrvMS: Double.random(in: 35...65),
                restingHeartRate: Double.random(in: 52...68),
                steps: Int.random(in: 5000...12000),
                activeEnergyKcal: Double.random(in: 200...600)
            )
            context.insert(snapshot)
        }

        // Achievements
        for type in AchievementType.allCases.prefix(4) {
            let achievement = Achievement(
                type: type,
                title: type.defaultTitle,
                detail: type.defaultDetail,
                icon: type.icon
            )
            if type == .firstLog {
                achievement.updateProgress(1)
            }
            context.insert(achievement)
        }

        profile.sampleDataLoaded = true
        try? context.save()
    }

    @MainActor
    static func previewContainer() -> ModelContainer {
        let schema = Schema(PeakSchema.allModels)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let context = container.mainContext
        let profile = UserProfile(appleUserID: "preview-user", displayName: "Alex Peak")
        profile.onboardingCompleted = true
        context.insert(profile)
        populate(context: context, profile: profile)
        return container
    }
}

enum PeakSchema {
    static let allModels: [any PersistentModel.Type] = [
        UserProfile.self,
        RecoveryScore.self,
        HabitDefinition.self,
        HabitLog.self,
        HydrationLog.self,
        MoodReflection.self,
        HealthSnapshot.self,
        JournalEntry.self,
        Achievement.self,
        CoachConversation.self,
        CoachMessage.self,
        AIUsageRecord.self,
        SubscriptionStateRecord.self,
    ]
}