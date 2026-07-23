import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class TrackViewModel {
    var habits: [HabitDefinition] = []
    var todayHabitLogs: [UUID: Bool] = [:]
    var hydrationML: Int = 0
    var hydrationGoal: Int = PeakConstants.Defaults.dailyWaterML
    var todayMood: MoodReflection?
    var recentMoods: [MoodReflection] = []
    var selectedSection: TrackSection = .habits

    enum TrackSection: String, CaseIterable {
        case habits = "Habits"
        case hydration = "Hydration"
        case mood = "Mood"
    }

    func load(modelContext: ModelContext) {
        habits = (try? modelContext.fetch(FetchDescriptor<HabitDefinition>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []

        let today = Date().startOfDay
        let logs = try? modelContext.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.date == today }
        ))
        todayHabitLogs = [:]
        for log in logs ?? [] {
            if let id = log.habit?.id {
                todayHabitLogs[id] = log.completed
            }
        }

        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            hydrationGoal = profile.dailyWaterGoalML
        }

        let hydrationLogs = try? modelContext.fetch(FetchDescriptor<HydrationLog>(
            predicate: #Predicate { $0.date >= today }
        ))
        hydrationML = hydrationLogs?.reduce(0) { $0 + $1.amountML } ?? 0

        recentMoods = (try? modelContext.fetch(FetchDescriptor<MoodReflection>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )))?.prefix(14).map { $0 } ?? []

        todayMood = recentMoods.first { $0.date.isToday }
    }

    func toggleHabit(_ habit: HabitDefinition, modelContext: ModelContext) {
        let today = Date().startOfDay
        let habitID = habit.id

        let descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.date == today }
        )
        let existing = try? modelContext.fetch(descriptor).first { $0.habit?.id == habitID }

        if let log = existing {
            log.completed.toggle()
            todayHabitLogs[habitID] = log.completed
        } else {
            let log = HabitLog(habit: habit, date: today, completed: true)
            modelContext.insert(log)
            todayHabitLogs[habitID] = true
        }

        try? modelContext.save()
        PeakHaptics.light()
    }

    func addHydration(ml: Int = PeakConstants.Defaults.habitGlassML, modelContext: ModelContext) {
        let log = HydrationLog(amountML: ml)
        modelContext.insert(log)
        hydrationML += ml
        try? modelContext.save()
        PeakHaptics.light()
    }

    func logMood(rating: Int, energy: Int, note: String?, tags: [String], modelContext: ModelContext) {
        let mood = MoodReflection(moodRating: rating, energyLevel: energy, note: note, tags: tags)
        modelContext.insert(mood)
        todayMood = mood
        recentMoods.insert(mood, at: 0)
        try? modelContext.save()
        PeakHaptics.success()
    }
}