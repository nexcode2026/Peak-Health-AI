import Foundation
import SwiftData
import SwiftUI

struct WellnessSignalDriver: Identifiable, Sendable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let impact: Double
    let icon: String
    let isSupportive: Bool
}

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
    var loggedEnergyLevel: Int?
    var loggedStressToday = false
    var recentRoutineConsistency: Double = 0

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

        let todayMood = try? modelContext.fetch(FetchDescriptor<MoodReflection>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )).first
        loggedEnergyLevel = todayMood?.energyLevel
        loggedStressToday = todayMood?.tags.contains(where: {
            $0.localizedCaseInsensitiveContains("stress") || $0.localizedCaseInsensitiveContains("restless")
        }) ?? false

        let routineStart = Calendar.current.date(byAdding: .day, value: -6, to: today) ?? today
        let recentHydration = (try? modelContext.fetch(FetchDescriptor<HydrationLog>(
            predicate: #Predicate { $0.date >= routineStart && $0.date < tomorrow }
        ))) ?? []
        let recentFood = (try? modelContext.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= routineStart && $0.date < tomorrow }
        ))) ?? []
        let recentWorkouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>(
            predicate: #Predicate { $0.date >= routineStart && $0.date < tomorrow }
        ))) ?? []
        let recentMoods = (try? modelContext.fetch(FetchDescriptor<MoodReflection>(
            predicate: #Predicate { $0.date >= routineStart && $0.date < tomorrow }
        ))) ?? []
        let routineDays = Set(
            recentHydration.map { $0.date.startOfDay }
                + recentFood.map { $0.date.startOfDay }
                + recentWorkouts.map { $0.date.startOfDay }
                + recentMoods.map { $0.date.startOfDay }
        )
        recentRoutineConsistency = min(1, Double(routineDays.count) / 7)

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

    /// Estimated wellness load, not a medical stress measurement. Higher means
    /// more recovery pressure from sleep, strain, fuel, hydration and routines.
    var stressLoad: Int {
        let recovery = Double(todayScore?.overallScore ?? 50)
        let sleepDeficit = max(0, 1 - sleepProgress)
        let hydrationDeficit = max(0, 1 - hydrationProgress)
        let nutritionDeficit = max(0, 1 - max(calorieProgress, proteinProgress))
        let strainPressure = max(0, Double(strainPercent - 65)) * 0.30
        let energyPressure = loggedEnergyLevel.map { Double(max(0, 3 - $0)) * 6 } ?? 0
        let taggedStress = loggedStressToday ? 14.0 : 0
        let routineBuffer = recentRoutineConsistency * 10
        let value = 48
            + (50 - recovery) * 0.38
            + sleepDeficit * 20
            + hydrationDeficit * 14
            + nutritionDeficit * 8
            + strainPressure
            + energyPressure
            + taggedStress
            - routineBuffer
        return Int(min(100, max(0, value)).rounded())
    }

    var stressLabel: String {
        switch stressLoad {
        case ..<35: "Low load"
        case 35..<60: "Balanced"
        case 60..<80: "Elevated"
        default: "High load"
        }
    }

    var stressDetail: String {
        if loggedStressToday { return "Your check-in and recovery inputs suggest extra load" }
        if sleepProgress < 0.75 { return "Sleep is the strongest pressure signal today" }
        if hydrationProgress < 0.5 { return "Hydration is adding to today’s load" }
        return "Blends recovery, strain, fuel and 7-day routines"
    }

    var energyScore: Int {
        let recovery = Double(todayScore?.overallScore ?? 50) / 100
        let moodEnergy = loggedEnergyLevel.map { Double($0) / 5 } ?? 0.6
        let value = recovery * 35
            + sleepProgress * 20
            + hydrationProgress * 15
            + max(calorieProgress, proteinProgress) * 10
            + recentRoutineConsistency * 10
            + moodEnergy * 10
        return Int(min(100, max(0, value)).rounded())
    }

    var energyLabel: String {
        switch energyScore {
        case ..<35: "Recharge"
        case 35..<60: "Steady"
        case 60..<80: "Ready"
        default: "Peak energy"
        }
    }

    var energyDetail: String {
        if let loggedEnergyLevel {
            return "Check-in \(loggedEnergyLevel)/5 · adjusted with live health data"
        }
        if hydrationProgress < 0.5 { return "Hydration can lift your available energy" }
        return "Recovery, sleep, nutrition and routines combined"
    }

    var stressDrivers: [WellnessSignalDriver] {
        let recovery = Double(todayScore?.overallScore ?? 50)
        let sleepDeficit = max(0, 1 - sleepProgress)
        let hydrationDeficit = max(0, 1 - hydrationProgress)
        let nutritionDeficit = max(0, 1 - max(calorieProgress, proteinProgress))
        let strainPressure = max(0, Double(strainPercent - 65)) * 0.30
        let checkInPressure = loggedEnergyLevel.map { Double(max(0, 3 - $0)) * 6 } ?? 0
        return [
            WellnessSignalDriver(
                id: "stress-recovery",
                title: "Recovery",
                value: "\(Int(recovery))/100",
                detail: recovery >= 60 ? "Recovery is buffering daily load." : "Lower recovery raises today’s estimated pressure.",
                impact: (50 - recovery) * 0.38,
                icon: "heart.circle.fill",
                isSupportive: recovery >= 60
            ),
            WellnessSignalDriver(
                id: "stress-sleep",
                title: "Sleep",
                value: "\(Int(sleepProgress * 100))% of goal",
                detail: sleepDeficit > 0.25 ? "Sleep debt is a leading pressure signal." : "Sleep duration is supporting resilience.",
                impact: sleepDeficit * 20,
                icon: "moon.zzz.fill",
                isSupportive: sleepDeficit <= 0.25
            ),
            WellnessSignalDriver(
                id: "stress-hydration",
                title: "Hydration",
                value: "\(Int(hydrationProgress * 100))% of goal",
                detail: hydrationDeficit > 0.5 ? "Low logged hydration increases the estimate." : "Hydration is near your current target.",
                impact: hydrationDeficit * 14,
                icon: "drop.fill",
                isSupportive: hydrationDeficit <= 0.5
            ),
            WellnessSignalDriver(
                id: "stress-fuel",
                title: "Nutrition",
                value: "\(Int(max(calorieProgress, proteinProgress) * 100))% fueled",
                detail: nutritionDeficit > 0.5 ? "Limited fuel data adds uncertainty and pressure." : "Logged nutrition is supporting the day.",
                impact: nutritionDeficit * 8,
                icon: "fork.knife",
                isSupportive: nutritionDeficit <= 0.5
            ),
            WellnessSignalDriver(
                id: "stress-training",
                title: "Activity load",
                value: "\(strainPercent) strain",
                detail: strainPressure > 0 ? "Activity above the balanced zone adds load." : "Training load is within the balanced zone.",
                impact: strainPressure,
                icon: "figure.run",
                isSupportive: strainPressure == 0
            ),
            WellnessSignalDriver(
                id: "stress-check-in",
                title: "Check-in",
                value: loggedEnergyLevel.map { "Energy \($0)/5" } ?? "Not logged",
                detail: loggedStressToday ? "Stress or restlessness was included in today’s check-in." : "A mood check-in makes this estimate more personal.",
                impact: checkInPressure + (loggedStressToday ? 14 : 0),
                icon: "face.smiling",
                isSupportive: !loggedStressToday && checkInPressure == 0
            ),
            WellnessSignalDriver(
                id: "stress-routine",
                title: "Routine consistency",
                value: "\(Int(recentRoutineConsistency * 100))%",
                detail: "Consistent recent logging and routines provide a protective buffer.",
                impact: -(recentRoutineConsistency * 10),
                icon: "calendar.badge.checkmark",
                isSupportive: true
            ),
        ]
    }

    var energyDrivers: [WellnessSignalDriver] {
        let recovery = Double(todayScore?.overallScore ?? 50) / 100
        let moodEnergy = loggedEnergyLevel.map { Double($0) / 5 } ?? 0.6
        return [
            WellnessSignalDriver(id: "energy-recovery", title: "Recovery", value: "\(Int(recovery * 100))/100", detail: "Recovery contributes up to 35 points.", impact: recovery * 35, icon: "heart.circle.fill", isSupportive: recovery >= 0.6),
            WellnessSignalDriver(id: "energy-sleep", title: "Sleep", value: "\(Int(sleepProgress * 100))% of goal", detail: "Sleep contributes up to 20 points.", impact: sleepProgress * 20, icon: "moon.zzz.fill", isSupportive: sleepProgress >= 0.75),
            WellnessSignalDriver(id: "energy-hydration", title: "Hydration", value: "\(Int(hydrationProgress * 100))% of goal", detail: "Hydration contributes up to 15 points.", impact: hydrationProgress * 15, icon: "drop.fill", isSupportive: hydrationProgress >= 0.5),
            WellnessSignalDriver(id: "energy-fuel", title: "Nutrition", value: "\(Int(max(calorieProgress, proteinProgress) * 100))% fueled", detail: "Calories and protein contribute up to 10 points.", impact: max(calorieProgress, proteinProgress) * 10, icon: "fork.knife", isSupportive: max(calorieProgress, proteinProgress) >= 0.5),
            WellnessSignalDriver(id: "energy-routine", title: "Routine", value: "\(Int(recentRoutineConsistency * 100))%", detail: "Recent consistency contributes up to 10 points.", impact: recentRoutineConsistency * 10, icon: "calendar.badge.checkmark", isSupportive: recentRoutineConsistency >= 0.6),
            WellnessSignalDriver(id: "energy-check-in", title: "Check-in energy", value: loggedEnergyLevel.map { "\($0)/5" } ?? "Estimated", detail: loggedEnergyLevel == nil ? "Peak uses a neutral baseline until you check in." : "Your reported energy contributes up to 10 points.", impact: moodEnergy * 10, icon: "bolt.fill", isSupportive: moodEnergy >= 0.6),
        ]
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
