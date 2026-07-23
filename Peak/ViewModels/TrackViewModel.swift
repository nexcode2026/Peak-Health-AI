import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class TrackViewModel {
    var habits: [HabitDefinition] = []
    var todayHabitLogs: [UUID: Bool] = [:]
    var habitStreaks: [UUID: Int] = [:]
    var habitWeeklyRates: [UUID: Double] = [:]
    var hydrationML: Int = 0
    var hydrationGoal: Int = PeakConstants.Defaults.dailyWaterML
    var unitSystem: UnitSystem = .metric
    var hydrationLogs: [HydrationLog] = []
    var todayMood: MoodReflection?
    var recentMoods: [MoodReflection] = []
    var todayFood: [FoodLog] = []
    var todayCalories: Int = 0
    var todayProtein: Double = 0
    var calorieGoal: Int = PeakConstants.Defaults.dailyCalorieGoal
    var proteinGoal: Int = PeakConstants.Defaults.dailyProteinGoalG
    var todayWorkouts: [WorkoutLog] = []
    var weeklyWorkoutCount: Int = 0
    var weeklyWorkoutGoal: Int = PeakConstants.Defaults.weeklyWorkoutGoal
    var weeklyWorkoutMinutes: Double = 0
    var weeklyCaloriesBurned: Double = 0
    var selectedSection: TrackSection = .habits
    var selectedDate: Date = Date().startOfDay

    enum TrackSection: String, CaseIterable, Identifiable {
        case habits = "Habits"
        case water = "Water"
        case food = "Food"
        case workouts = "Workouts"
        case mood = "Mood"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .habits: return "checkmark.circle"
            case .water: return "drop.fill"
            case .food: return "fork.knife"
            case .workouts: return "figure.run"
            case .mood: return "face.smiling"
            }
        }
    }

    func load(modelContext: ModelContext, date: Date? = nil) {
        let today = (date ?? selectedDate).startOfDay
        selectedDate = today
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -6, to: today)?.startOfDay ?? today
        let weekEnd = tomorrow

        habits = (try? modelContext.fetch(FetchDescriptor<HabitDefinition>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []

        let logs = try? modelContext.fetch(FetchDescriptor<HabitLog>(predicate: #Predicate { $0.date == today }))
        todayHabitLogs = [:]
        for log in logs ?? [] {
            if let id = log.habit?.id { todayHabitLogs[id] = log.completed }
        }

        let habitHistoryStart = Calendar.current.date(byAdding: .day, value: -35, to: today)?.startOfDay ?? today
        let habitHistory = (try? modelContext.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.date >= habitHistoryStart && $0.date < tomorrow && $0.completed }
        ))) ?? []
        computeHabitStats(logs: habitHistory, today: today)

        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            hydrationGoal = profile.dailyWaterGoalML
            unitSystem = UnitSystem(preferredUnits: profile.preferredUnits)
            calorieGoal = profile.dailyCalorieGoal
            proteinGoal = profile.dailyProteinGoalG
            weeklyWorkoutGoal = profile.weeklyWorkoutGoal
        }

        hydrationLogs = (try? modelContext.fetch(FetchDescriptor<HydrationLog>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))) ?? []
        hydrationML = hydrationLogs.reduce(0) { $0 + $1.amountML }

        todayFood = (try? modelContext.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))) ?? []
        todayCalories = todayFood.reduce(0) { $0 + $1.calories }
        todayProtein = todayFood.reduce(0) { $0 + $1.proteinG }

        todayWorkouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))) ?? []
        let weeklyWorkouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>(
            predicate: #Predicate { $0.date >= weekAgo && $0.date < weekEnd }
        ))) ?? []
        weeklyWorkoutCount = weeklyWorkouts.count
        weeklyWorkoutMinutes = weeklyWorkouts.reduce(0) { $0 + $1.durationMinutes }
        weeklyCaloriesBurned = weeklyWorkouts.reduce(0) { $0 + $1.caloriesBurned }

        recentMoods = (try? modelContext.fetch(FetchDescriptor<MoodReflection>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )))?.prefix(14).map { $0 } ?? []
        todayMood = (try? modelContext.fetch(FetchDescriptor<MoodReflection>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )))?.first
    }

    func toggleHabit(_ habit: HabitDefinition, modelContext: ModelContext) {
        let today = selectedDate.startOfDay
        let habitID = habit.id
        let existing = try? modelContext.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.date == today }
        )).first { $0.habit?.id == habitID }

        if let log = existing {
            log.completed.toggle()
            todayHabitLogs[habitID] = log.completed
        } else {
            let log = HabitLog(habit: habit, date: today, completed: true)
            modelContext.insert(log)
            todayHabitLogs[habitID] = true
        }
        try? modelContext.save()
        if PeakHapticsEnabled(modelContext: modelContext) { PeakHaptics.light() }
    }

    func addHydration(ml: Int = PeakConstants.Defaults.habitGlassML, beverage: BeverageType = .water, modelContext: ModelContext) {
        let log = HydrationLog(amountML: ml, beverageType: beverage, date: selectedDate)
        modelContext.insert(log)
        hydrationML += ml
        hydrationLogs.insert(log, at: 0)
        try? modelContext.save()
        if PeakHapticsEnabled(modelContext: modelContext) { PeakHaptics.light() }
    }

    func logMood(rating: Int, energy: Int, note: String?, tags: [String], modelContext: ModelContext) {
        let mood: MoodReflection
        if let existing = todayMood {
            existing.moodRating = rating.clamped(to: 1...5)
            existing.energyLevel = energy.clamped(to: 1...5)
            existing.note = note
            existing.tags = tags
            existing.updatedAt = .now
            mood = existing
            recentMoods.removeAll { $0.id == existing.id }
        } else {
            mood = MoodReflection(moodRating: rating, energyLevel: energy, note: note, tags: tags, date: selectedDate)
            modelContext.insert(mood)
        }
        todayMood = mood
        recentMoods.insert(mood, at: 0)
        try? modelContext.save()
        if PeakHapticsEnabled(modelContext: modelContext) { PeakHaptics.success() }
    }

    func deleteHabit(_ habit: HabitDefinition, modelContext: ModelContext) {
        habit.isActive = false
        try? modelContext.save()
        load(modelContext: modelContext)
    }

    func deleteHydration(_ log: HydrationLog, modelContext: ModelContext) {
        modelContext.delete(log)
        hydrationLogs.removeAll { $0.id == log.id }
        hydrationML = max(0, hydrationML - log.amountML)
        try? modelContext.save()
        PeakHaptics.light()
    }

    func deleteFood(_ food: FoodLog, modelContext: ModelContext) {
        modelContext.delete(food)
        todayFood.removeAll { $0.id == food.id }
        todayCalories = todayFood.reduce(0) { $0 + $1.calories }
        todayProtein = todayFood.reduce(0) { $0 + $1.proteinG }
        try? modelContext.save()
        PeakHaptics.light()
    }

    func deleteWorkout(_ workout: WorkoutLog, modelContext: ModelContext) {
        modelContext.delete(workout)
        todayWorkouts.removeAll { $0.id == workout.id }
        weeklyWorkoutCount = max(0, weeklyWorkoutCount - 1)
        weeklyWorkoutMinutes = max(0, weeklyWorkoutMinutes - workout.durationMinutes)
        weeklyCaloriesBurned = max(0, weeklyCaloriesBurned - workout.caloriesBurned)
        try? modelContext.save()
        PeakHaptics.light()
    }

    func deleteMood(_ mood: MoodReflection, modelContext: ModelContext) {
        modelContext.delete(mood)
        recentMoods.removeAll { $0.id == mood.id }
        if todayMood?.id == mood.id { todayMood = nil }
        try? modelContext.save()
        PeakHaptics.light()
    }

    private func computeHabitStats(logs: [HabitLog], today: Date) {
        habitStreaks = [:]
        habitWeeklyRates = [:]
        let calendar = Calendar.current

        for habit in habits {
            let days = Set(logs.compactMap { log -> Date? in
                guard log.habit?.id == habit.id else { return nil }
                return log.date.startOfDay
            })

            var cursor = today
            if !days.contains(cursor) {
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor)?.startOfDay ?? cursor
            }

            var streak = 0
            while days.contains(cursor) {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous.startOfDay
            }
            habitStreaks[habit.id] = streak

            let weeklyCompleted = (0..<7).reduce(0) { partial, offset in
                let date = calendar.date(byAdding: .day, value: -offset, to: today)?.startOfDay ?? today
                return partial + (days.contains(date) ? 1 : 0)
            }
            habitWeeklyRates[habit.id] = Double(weeklyCompleted) / 7
        }
    }

    private func PeakHapticsEnabled(modelContext: ModelContext) -> Bool {
        (try? modelContext.fetch(FetchDescriptor<UserProfile>()).first?.hapticsEnabled) ?? true
    }

    var hydrationProgress: Double {
        guard hydrationGoal > 0 else { return 0 }
        return min(1, Double(hydrationML) / Double(hydrationGoal))
    }

    var hydrationRemainingML: Int {
        max(0, hydrationGoal - hydrationML)
    }

    var suggestedNextDrinkML: Int {
        guard hydrationRemainingML > 0 else { return 0 }
        guard selectedDate.isToday else { return min(500, max(200, hydrationRemainingML)) }
        let hour = Calendar.current.component(.hour, from: .now)
        let remainingWindows = max(1, (22 - hour + 1) / 2)
        let paced = Int(ceil(Double(hydrationRemainingML) / Double(remainingWindows) / 50)) * 50
        return min(500, max(200, paced))
    }

    var hydrationPaceMessage: String {
        let formatter = UnitFormatter(system: unitSystem)
        guard hydrationRemainingML > 0 else { return "Goal complete—maintain normal thirst cues." }
        guard selectedDate.isToday else {
            return "Historical total: \(formatter.formatWater(hydrationML)) of \(formatter.formatWater(hydrationGoal))."
        }
        let components = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let hour = Double(components.hour ?? 12) + Double(components.minute ?? 0) / 60
        let expectedFraction = ((hour - 7) / 15).clamped(to: 0...1)
        if hydrationProgress + 0.08 >= expectedFraction {
            return "On pace. A \(formatter.formatWater(suggestedNextDrinkML)) drink keeps you steady."
        }
        let behind = max(0, Int(Double(hydrationGoal) * expectedFraction) - hydrationML)
        return "About \(formatter.formatWater(behind)) behind pace. Sip \(formatter.formatWater(suggestedNextDrinkML)) over the next hour."
    }

    var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(1, Double(todayCalories) / Double(calorieGoal))
    }

    var caloriesRemaining: Int {
        max(0, calorieGoal - todayCalories)
    }

    var proteinRemaining: Int {
        max(0, proteinGoal - Int(todayProtein))
    }

    var sevenDayMoodAverage: Double? {
        let entries = recentMoods.filter { $0.date >= Date().daysAgo(7) }
        guard !entries.isEmpty else { return nil }
        return Double(entries.reduce(0) { $0 + $1.moodRating }) / Double(entries.count)
    }

    var habitsCompletedCount: Int {
        todayHabitLogs.values.filter { $0 }.count
    }
}
