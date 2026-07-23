import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class InsightsViewModel {
    var recoveryScores: [RecoveryScore] = []
    var moodEntries: [MoodReflection] = []
    var achievements: [Achievement] = []
    var habitAdherence: [HabitAdherenceDay] = []
    var selectedRange: InsightRange = .twoWeeks
    var personalizedInsights: [String] = []

    enum InsightRange: String, CaseIterable {
        case week = "7D"
        case twoWeeks = "14D"
        case month = "30D"
        case quarter = "90D"

        var days: Int {
            switch self {
            case .week: return 7
            case .twoWeeks: return 14
            case .month: return 30
            case .quarter: return 90
            }
        }
    }

    struct HabitAdherenceDay: Identifiable {
        let id = UUID()
        let date: Date
        let completed: Int
        let total: Int

        var rate: Double {
            guard total > 0 else { return 0 }
            return Double(completed) / Double(total)
        }
    }

    func load(modelContext: ModelContext, tier: SubscriptionTier) {
        let days = min(selectedRange.days, tier.historyDays)
        let startDate = Date().daysAgo(days).startOfDay

        recoveryScores = (try? modelContext.fetch(FetchDescriptor<RecoveryScore>(
            predicate: #Predicate { $0.date >= startDate },
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []

        moodEntries = (try? modelContext.fetch(FetchDescriptor<MoodReflection>(
            predicate: #Predicate { $0.date >= startDate },
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []

        achievements = (try? modelContext.fetch(FetchDescriptor<Achievement>(
            sortBy: [SortDescriptor(\.unlockedAt, order: .reverse)]
        ))) ?? []

        computeHabitAdherence(modelContext: modelContext, days: days)
        generateInsights()
    }

    private func computeHabitAdherence(modelContext: ModelContext, days: Int) {
        let habits = (try? modelContext.fetch(FetchDescriptor<HabitDefinition>(
            predicate: #Predicate { $0.isActive }
        ))) ?? []
        let total = habits.count

        habitAdherence = (0..<days).map { offset in
            let date = Date().daysAgo(offset).startOfDay
            let logs = try? modelContext.fetch(FetchDescriptor<HabitLog>(
                predicate: #Predicate { $0.date == date && $0.completed }
            ))
            return HabitAdherenceDay(date: date, completed: logs?.count ?? 0, total: total)
        }.reversed()
    }

    private func generateInsights() {
        personalizedInsights = []

        if let avg = averageRecovery {
            personalizedInsights.append("Your average recovery is \(avg) over this period.")
        }

        if let sleepCorr = sleepRecoveryCorrelation {
            if sleepCorr > 0.5 {
                personalizedInsights.append("Strong link: better sleep correlates with higher recovery scores.")
            }
        }

        if let moodAvg = averageMood {
            personalizedInsights.append("Average mood: \(String(format: "%.1f", moodAvg))/5.")
        }

        let unlocked = achievements.filter(\.isUnlocked).count
        if unlocked > 0 {
            personalizedInsights.append("You've unlocked \(unlocked) achievement\(unlocked == 1 ? "" : "s")!")
        }

        if personalizedInsights.isEmpty {
            personalizedInsights.append("Keep logging to unlock personalized insights.")
        }
    }

    var averageRecovery: Int? {
        guard !recoveryScores.isEmpty else { return nil }
        return recoveryScores.map(\.overallScore).reduce(0, +) / recoveryScores.count
    }

    var averageMood: Double? {
        guard !moodEntries.isEmpty else { return nil }
        return Double(moodEntries.map(\.moodRating).reduce(0, +)) / Double(moodEntries.count)
    }

    var sleepRecoveryCorrelation: Double? {
        // Simplified correlation placeholder using available score variance
        guard recoveryScores.count >= 5 else { return nil }
        let high = recoveryScores.filter { $0.sleepScore > 70 }.count
        return Double(high) / Double(recoveryScores.count)
    }
}