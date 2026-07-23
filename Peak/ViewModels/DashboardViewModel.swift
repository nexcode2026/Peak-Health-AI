import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    enum QuickAction: String, Identifiable, Sendable {
        case water
        case meal
        case workout
        case mood

        var id: String { rawValue }
    }

    struct DailyPlanItem: Identifiable, Sendable {
        enum Tone: Sendable { case recovery, hydration, nutrition, movement, mindfulness, habits }

        let id: String
        let title: String
        let detail: String
        let icon: String
        let tone: Tone
        let progress: Double
        let action: QuickAction?

        var isComplete: Bool { progress >= 1 }
    }

    var todayScore: RecoveryScore?
    var healthMetrics: DailyHealthMetrics?
    var hydrationML: Int = 0
    var hydrationGoal: Int = PeakConstants.Defaults.dailyWaterML
    var sleepTarget: Double = PeakConstants.Defaults.sleepHoursTarget
    var unitSystem: UnitSystem = .metric
    var habitsCompleted: Int = 0
    var habitsTotal: Int = 0
    var todayCalories: Int = 0
    var todayProtein: Double = 0
    var calorieGoal: Int = PeakConstants.Defaults.dailyCalorieGoal
    var proteinGoal: Int = PeakConstants.Defaults.dailyProteinGoalG
    var todayWorkouts: Int = 0
    var selectedDate: Date = Date().startOfDay
    var recentAchievements: [Achievement] = []
    var nearestAchievements: [Achievement] = []
    var dailyInsight: String = ""
    var isLoading = false
    var wellnessStatus: WellnessStatus = .normal

    func load(date: Date = .now, modelContext: ModelContext, container: AppContainer) async {
        isLoading = true
        defer { isLoading = false }

        let today = date.startOfDay
        selectedDate = today
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        todayScore = try? modelContext.fetch(FetchDescriptor<RecoveryScore>(
            predicate: #Predicate { $0.date == today }
        )).first

        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            hydrationGoal = profile.dailyWaterGoalML
            sleepTarget = profile.sleepHoursTarget
            unitSystem = UnitSystem(preferredUnits: profile.preferredUnits)
            calorieGoal = profile.dailyCalorieGoal
            proteinGoal = profile.dailyProteinGoalG
            wellnessStatus = profile.wellnessStatus
        }

        hydrationML = (try? modelContext.fetch(FetchDescriptor<HydrationLog>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        )))?.reduce(0) { $0 + $1.amountML } ?? 0

        let foodLogs = (try? modelContext.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        ))) ?? []
        todayCalories = foodLogs.reduce(0) { $0 + $1.calories }
        todayProtein = foodLogs.reduce(0) { $0 + $1.proteinG }

        todayWorkouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        )))?.count ?? 0

        habitsTotal = (try? modelContext.fetch(FetchDescriptor<HabitDefinition>(
            predicate: #Predicate { $0.isActive }
        )))?.count ?? 0

        habitsCompleted = (try? modelContext.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.date == today && $0.completed }
        )))?.count ?? 0

        recentAchievements = (try? modelContext.fetch(FetchDescriptor<Achievement>(
            predicate: #Predicate { $0.unlockedAt != nil },
            sortBy: [SortDescriptor(\.unlockedAt, order: .reverse)]
        )))?.prefix(4).map { $0 } ?? []

        nearestAchievements = AchievementService.nearestUnlocks(modelContext: modelContext)

        if today.isToday {
            await container.refreshAll(modelContext: modelContext)
            healthMetrics = container.healthData.mergedMetrics()
        } else {
            await container.healthData.refresh(modelContext: modelContext, date: today)
            healthMetrics = container.healthData.todayMetrics
        }
        todayScore = try? modelContext.fetch(scoreDescriptor(today)).first
        generateInsight(container: container)
    }

    private func scoreDescriptor(_ today: Date) -> FetchDescriptor<RecoveryScore> {
        FetchDescriptor<RecoveryScore>(predicate: #Predicate { $0.date == today })
    }

    private func generateInsight(container: AppContainer) {
        if wellnessStatus != .normal {
            dailyInsight = wellnessStatus.guidance
            return
        }
        guard let score = todayScore else {
            dailyInsight = selectedDate.isToday
                ? container.healthData.authorizationStatus.displayMessage
                : "No recovery score was saved for this day. Sleep, activity, nutrition, water, and journal history are still shown when available."
            return
        }
        if score.overallScore >= 80 {
            dailyInsight = "Peak form today. Your body is ready — consider pushing your limits safely."
        } else if score.overallScore >= 60 {
            dailyInsight = "Solid recovery. Hit your water and protein goals to climb higher."
        } else {
            dailyInsight = "Recovery is lower. Prioritize sleep tonight and keep logging consistently."
        }
    }

    var hydrationProgress: Double {
        guard hydrationGoal > 0 else { return 0 }
        return min(1, Double(hydrationML) / Double(hydrationGoal))
    }

    var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(1, Double(todayCalories) / Double(calorieGoal))
    }

    var proteinProgress: Double {
        guard proteinGoal > 0 else { return 0 }
        return min(1, todayProtein / Double(proteinGoal))
    }

    var moveProgress: Double {
        let steps = healthMetrics?.steps ?? 0
        guard steps > 0 else { return 0 }
        return min(1, Double(steps) / Double(PeakConstants.Defaults.dailyStepsGoal))
    }

    var strainPercent: Int {
        healthMetrics.map { Int($0.strainBalance * 100) } ?? 0
    }

    var sleepHoursDisplay: Double {
        healthMetrics?.sleepHours ?? 0
    }

    var sleepScore: Int {
        Int(todayScore?.sleepScore ?? 0)
    }

    var sleepProgress: Double {
        guard sleepTarget > 0 else { return 0 }
        return min(1, sleepHoursDisplay / sleepTarget)
    }

    var strainScore: Int {
        Int(todayScore?.activityScore ?? Double(strainPercent))
    }

    var stepsDisplay: Int {
        healthMetrics?.steps ?? 0
    }

    var activeCaloriesDisplay: Int {
        Int(healthMetrics?.activeEnergyKcal ?? 0)
    }

    var dailyPlan: [DailyPlanItem] {
        var items: [DailyPlanItem] = []
        let recovery = todayScore?.overallScore ?? 0
        let sleep = sleepHoursDisplay

        if wellnessStatus == .sick {
            items.append(DailyPlanItem(
                id: "status-sick",
                title: "Make recovery the priority",
                detail: "Keep activity gentle, hydrate consistently, and seek medical advice for concerning or worsening symptoms.",
                icon: "cross.case.fill",
                tone: .recovery,
                progress: 0,
                action: nil
            ))
        } else if wellnessStatus == .injured {
            items.append(DailyPlanItem(
                id: "status-injured",
                title: "Protect the injured area",
                detail: "Choose only comfortable activity that follows your clinician or rehabilitation plan.",
                icon: "bandage.fill",
                tone: .recovery,
                progress: 0,
                action: nil
            ))
        } else if wellnessStatus == .resting {
            items.append(DailyPlanItem(
                id: "status-resting",
                title: "Honor your recovery day",
                detail: "Mobility, easy walking, hydration, and sleep consistency are enough today.",
                icon: "figure.mind.and.body",
                tone: .recovery,
                progress: 0,
                action: nil
            ))
        } else if wellnessStatus == .traveling {
            items.append(DailyPlanItem(
                id: "status-traveling",
                title: "Anchor your travel day",
                detail: "Use local daylight, regular water, and short movement breaks to support sleep timing.",
                icon: "airplane",
                tone: .movement,
                progress: 0,
                action: .water
            ))
        } else if sleep > 0, sleep < 7 {
            items.append(DailyPlanItem(
                id: "sleep",
                title: "Protect tonight's sleep",
                detail: "Last night was \(sleep.formattedOneDecimal)h. Start winding down 30–45 minutes earlier.",
                icon: "moon.zzz.fill",
                tone: .recovery,
                progress: min(1, sleep / 8),
                action: nil
            ))
        } else if recovery >= 80 {
            items.append(DailyPlanItem(
                id: "training",
                title: "Use your training window",
                detail: todayWorkouts > 0 ? "Workout logged. Keep the rest of the day recovery-focused." : "Recovery is high—today can support a quality training session.",
                icon: "figure.run.circle.fill",
                tone: .movement,
                progress: todayWorkouts > 0 ? 1 : 0,
                action: todayWorkouts > 0 ? nil : .workout
            ))
        } else {
            items.append(DailyPlanItem(
                id: "movement",
                title: recovery > 0 && recovery < 55 ? "Choose restorative movement" : "Build easy movement",
                detail: recovery > 0 && recovery < 55 ? "Keep intensity conversational: walk, mobility, or gentle cycling." : "A short walk helps energy, glucose response, and sleep pressure.",
                icon: "figure.walk.circle.fill",
                tone: .movement,
                progress: min(1, Double(stepsDisplay) / 7_500),
                action: .workout
            ))
        }

        let waterRemaining = max(0, hydrationGoal - hydrationML)
        let nextDrink = min(500, max(250, waterRemaining))
        let unitFormatter = UnitFormatter(system: unitSystem)
        items.append(DailyPlanItem(
            id: "hydration",
            title: waterRemaining == 0 ? "Hydration goal complete" : "Drink \(unitFormatter.formatWater(nextDrink)) next",
            detail: waterRemaining == 0 ? "You reached today's water target." : "\(unitFormatter.formatWater(waterRemaining)) remains to reach today's target.",
            icon: waterRemaining == 0 ? "checkmark.circle.fill" : "drop.circle.fill",
            tone: .hydration,
            progress: hydrationProgress,
            action: waterRemaining == 0 ? nil : .water
        ))

        let proteinRemaining = max(0, proteinGoal - Int(todayProtein))
        items.append(DailyPlanItem(
            id: "protein",
            title: proteinRemaining == 0 ? "Protein target complete" : "Plan \(proteinRemaining)g more protein",
            detail: proteinRemaining == 0 ? "Today's logged meals cover your protein target." : "Spread the remainder across your next meal or snack.",
            icon: proteinRemaining == 0 ? "checkmark.circle.fill" : "fork.knife.circle.fill",
            tone: .nutrition,
            progress: proteinProgress,
            action: proteinRemaining == 0 ? nil : .meal
        ))

        if habitsTotal > 0 {
            let remaining = max(0, habitsTotal - habitsCompleted)
            items.append(DailyPlanItem(
                id: "habits",
                title: remaining == 0 ? "Micro-habits complete" : "Finish \(remaining) micro-habit\(remaining == 1 ? "" : "s")",
                detail: remaining == 0 ? "Consistency is compounding." : "Small completions can lift today's recovery inputs.",
                icon: remaining == 0 ? "checkmark.seal.fill" : "checkmark.circle",
                tone: .habits,
                progress: Double(habitsCompleted) / Double(max(1, habitsTotal)),
                action: nil
            ))
        }

        if todayScore?.factors.moodRating == 0 {
            items.append(DailyPlanItem(
                id: "mood",
                title: "Take a 20-second check-in",
                detail: "Log mood and energy to make your recovery picture more personal.",
                icon: "face.smiling.inverse",
                tone: .mindfulness,
                progress: 0,
                action: .mood
            ))
        }

        return Array(items.prefix(5))
    }

    var dailyPlanProgress: Double {
        guard !dailyPlan.isEmpty else { return 0 }
        return dailyPlan.map(\.progress).reduce(0, +) / Double(dailyPlan.count)
    }

    var journalProgress: Double {
        let habitProgress = habitsTotal > 0 ? Double(habitsCompleted) / Double(habitsTotal) : 0
        let moodProgress = (todayScore?.factors.moodRating ?? 0) > 0 ? 1.0 : 0.0
        return habitsTotal > 0 ? (habitProgress + moodProgress) / 2 : moodProgress
    }
}
