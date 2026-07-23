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

        // Food logs
        let meals: [(String, MealType, Int)] = [
            ("Oatmeal & Berries", .breakfast, 320),
            ("Chicken Salad", .lunch, 450),
            ("Protein Shake", .snack, 180),
            ("Salmon & Rice", .dinner, 580),
        ]
        for (name, meal, cal) in meals {
            let food = FoodLog(name: name, mealType: meal, calories: cal, proteinG: Double(cal) / 15)
            context.insert(food)
        }

        // Workout logs
        let workouts: [(WorkoutType, Double)] = [(.running, 35), (.strength, 45), (.yoga, 30)]
        for (type, mins) in workouts {
            let w = WorkoutLog(name: type.displayName, workoutType: type, durationMinutes: mins, caloriesBurned: type.kcalPerMinute * mins)
            context.insert(w)
        }

        profile.bio = "Chasing peak performance, one habit at a time."
        profile.heightCm = 175
        profile.weightKg = 72
        profile.dailyCalorieGoal = 2400
        profile.dailyProteinGoalG = 140
        profile.weeklyWorkoutGoal = 5

        AchievementService.ensureAllAchievementsExist(modelContext: context)
        AchievementService.evaluateAll(modelContext: context)

        profile.sampleDataLoaded = true
        try? context.save()
    }

    @MainActor
    static func previewContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)

        if let container = try? ModelContainer(
            for: Schema(versionedSchema: PeakSchemaV1.self),
            migrationPlan: PeakMigrationPlan.self,
            configurations: [config]
        ) {
            return seedPreviewData(in: container)
        }

        if let container = try? ModelContainer(
            for: Schema(PeakSchema.allModels),
            configurations: [config]
        ) {
            return seedPreviewData(in: container)
        }

        // Canvas fallback — minimal in-memory store.
        guard let fallback = try? ModelContainer(
            for: Schema([UserProfile.self]),
            configurations: [config]
        ) else {
            PeakLogger.cloudKit.fault("Preview ModelContainer creation failed.")
            return seedPreviewData(in: minimalPreviewContainer(config: config))
        }
        return seedPreviewData(in: fallback)
    }

    @MainActor
    private static func minimalPreviewContainer(config: ModelConfiguration) -> ModelContainer {
        // Canvas-only fallback; app launch never calls this path.
        if let container = try? ModelContainer(for: Schema([UserProfile.self]), configurations: [config]) {
            return container
        }
        PeakLogger.cloudKit.fault("Preview minimal ModelContainer failed — returning empty in-memory shell.")
        return (try? ModelContainer(
            for: Schema([UserProfile.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )) ?? {
            fatalError("Peak preview could not create any ModelContainer. Check @Model definitions in PeakSchema.")
        }()
    }

    @MainActor
    private static func seedPreviewData(in container: ModelContainer) -> ModelContainer {
        let context = container.mainContext
        if (try? context.fetch(FetchDescriptor<UserProfile>()).first) == nil {
            let profile = UserProfile(appleUserID: "preview-user", displayName: "Alex Peak")
            profile.onboardingCompleted = true
            profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -28, to: Date())
            profile.gender = GenderOption.male.rawValue
            profile.activityLevel = ActivityLevel.active.rawValue
            context.insert(profile)
            populate(context: context, profile: profile)
        }
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
        FoodLog.self,
        WorkoutLog.self,
        CycleEntry.self,
    ]
}
