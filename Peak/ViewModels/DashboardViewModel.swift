import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    var todayScore: RecoveryScore?
    var healthSnapshot: HealthSnapshot?
    var hydrationML: Int = 0
    var hydrationGoal: Int = PeakConstants.Defaults.dailyWaterML
    var habitsCompleted: Int = 0
    var habitsTotal: Int = 0
    var recentAchievements: [Achievement] = []
    var dailyInsight: String = ""
    var isLoading = false
    var error: PeakError?

    func load(modelContext: ModelContext, container: AppContainer) async {
        isLoading = true
        defer { isLoading = false }

        let today = Date().startOfDay

        let scoreDescriptor = FetchDescriptor<RecoveryScore>(
            predicate: #Predicate { $0.date == today }
        )
        todayScore = try? modelContext.fetch(scoreDescriptor).first

        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            hydrationGoal = profile.dailyWaterGoalML
        }

        let hydrationDescriptor = FetchDescriptor<HydrationLog>(
            predicate: #Predicate { $0.date >= today }
        )
        hydrationML = (try? modelContext.fetch(hydrationDescriptor))?.reduce(0) { $0 + $1.amountML } ?? 0

        let habits = try? modelContext.fetch(FetchDescriptor<HabitDefinition>(
            predicate: #Predicate { $0.isActive }
        ))
        habitsTotal = habits?.count ?? 0

        let logs = try? modelContext.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.date == today && $0.completed }
        ))
        habitsCompleted = logs?.count ?? 0

        recentAchievements = (try? modelContext.fetch(
            FetchDescriptor<Achievement>(
                predicate: #Predicate { $0.unlockedAt != nil },
                sortBy: [SortDescriptor(\.unlockedAt, order: .reverse)]
            )
        ))?.prefix(3).map { $0 } ?? []

        await container.refreshAll(modelContext: modelContext)
        todayScore = try? modelContext.fetch(scoreDescriptor).first

        generateInsight()
    }

    private func generateInsight() {
        guard let score = todayScore else {
            dailyInsight = "Log your habits and mood to unlock personalized insights."
            return
        }

        if score.overallScore >= 80 {
            dailyInsight = "You're in peak form today. Consider a challenging workout or new personal best."
        } else if score.overallScore >= 60 {
            dailyInsight = "Solid recovery. Focus on hydration and completing remaining habits."
        } else {
            dailyInsight = "Recovery is lower today. Prioritize rest, sleep, and gentle movement."
        }
    }

    var hydrationProgress: Double {
        guard hydrationGoal > 0 else { return 0 }
        return min(1, Double(hydrationML) / Double(hydrationGoal))
    }
}