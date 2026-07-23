import Foundation
import SwiftData
import SwiftUI

struct HealthTrendSample: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let recovery: Double
    let sleepHours: Double?
    let hydrationRate: Double?
    let mood: Double?
    let habitRate: Double?
}

enum RecoveryDriver: String, CaseIterable, Identifiable, Sendable {
    case sleep = "Sleep"
    case hydration = "Hydration"
    case mood = "Mood"
    case habits = "Habits"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sleep: "moon.fill"
        case .hydration: "drop.fill"
        case .mood: "face.smiling.fill"
        case .habits: "checkmark.circle.fill"
        }
    }
}

struct DriverCorrelation: Identifiable, Sendable {
    var id: RecoveryDriver { driver }
    let driver: RecoveryDriver
    let coefficient: Double
    let sampleCount: Int

    var strengthLabel: String {
        switch abs(coefficient) {
        case 0.7...: "Strong"
        case 0.4..<0.7: "Moderate"
        case 0.2..<0.4: "Emerging"
        default: "Weak"
        }
    }
}

struct RecoveryZoneCount: Identifiable, Sendable {
    let id: String
    let count: Int
    let lowerBound: Int
}

struct HealthAnalyticsSummary: Sendable {
    var trendDelta: Double?
    var consistencyScore: Int?
    var bestDay: HealthTrendSample?
    var loggingStreak: Int = 0
    var drivers: [DriverCorrelation] = []
    var zones: [RecoveryZoneCount] = []
}

enum HealthAnalyticsEngine {
    static func analyze(_ samples: [HealthTrendSample]) -> HealthAnalyticsSummary {
        let sorted = samples.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return HealthAnalyticsSummary() }

        var summary = HealthAnalyticsSummary()
        summary.bestDay = sorted.max { $0.recovery < $1.recovery }
        summary.loggingStreak = consecutiveDayStreak(dates: sorted.map(\.date))

        if sorted.count >= 4 {
            let midpoint = sorted.count / 2
            let earlier = sorted[..<midpoint].map(\.recovery)
            let recent = sorted[midpoint...].map(\.recovery)
            summary.trendDelta = average(recent) - average(earlier)
        }

        if sorted.count >= 3 {
            let values = sorted.map(\.recovery)
            let mean = average(values)
            let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
            let standardDeviation = sqrt(variance)
            summary.consistencyScore = Int((100 - standardDeviation * 2.5).clamped(to: 0...100))
        }

        let driverValues: [(RecoveryDriver, (HealthTrendSample) -> Double?)] = [
            (.sleep, { $0.sleepHours }),
            (.hydration, { $0.hydrationRate }),
            (.mood, { $0.mood }),
            (.habits, { $0.habitRate }),
        ]
        summary.drivers = driverValues.compactMap { driver, value in
            let pairs = sorted.compactMap { sample -> (Double, Double)? in
                guard let input = value(sample) else { return nil }
                return (input, sample.recovery)
            }
            guard let coefficient = pearson(pairs: pairs) else { return nil }
            return DriverCorrelation(driver: driver, coefficient: coefficient, sampleCount: pairs.count)
        }
        .sorted { abs($0.coefficient) > abs($1.coefficient) }

        summary.zones = [
            RecoveryZoneCount(id: "Peak", count: sorted.filter { $0.recovery >= 80 }.count, lowerBound: 80),
            RecoveryZoneCount(id: "Good", count: sorted.filter { $0.recovery >= 60 && $0.recovery < 80 }.count, lowerBound: 60),
            RecoveryZoneCount(id: "Easy", count: sorted.filter { $0.recovery >= 40 && $0.recovery < 60 }.count, lowerBound: 40),
            RecoveryZoneCount(id: "Recover", count: sorted.filter { $0.recovery < 40 }.count, lowerBound: 0),
        ]
        return summary
    }

    static func pearson(pairs: [(Double, Double)]) -> Double? {
        guard pairs.count >= 3 else { return nil }
        let xMean = average(pairs.map { $0.0 })
        let yMean = average(pairs.map { $0.1 })
        let numerator = pairs.reduce(0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) }
        let xDenominator = sqrt(pairs.reduce(0) { $0 + pow($1.0 - xMean, 2) })
        let yDenominator = sqrt(pairs.reduce(0) { $0 + pow($1.1 - yMean, 2) })
        let denominator = xDenominator * yDenominator
        guard denominator > 0 else { return nil }
        return (numerator / denominator).clamped(to: -1...1)
    }

    static func consecutiveDayStreak(dates: [Date]) -> Int {
        let calendar = Calendar.current
        let days = Set(dates.map { $0.startOfDay })
        guard var cursor = days.max() else { return 0 }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous.startOfDay
        }
        return streak
    }

    private static func average<C: Collection>(_ values: C) -> Double where C.Element == Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}

@MainActor
@Observable
final class InsightsViewModel {
    struct InsightFinding: Identifiable {
        enum Sentiment { case positive, attention, neutral }

        let id: String
        let icon: String
        let title: String
        let detail: String
        let sentiment: Sentiment
    }

    var recoveryScores: [RecoveryScore] = []
    var moodEntries: [MoodReflection] = []
    var achievements: [Achievement] = []
    var habitAdherence: [HabitAdherenceDay] = []
    var selectedRange: InsightRange = .twoWeeks
    var personalizedInsights: [InsightFinding] = []
    var analytics = HealthAnalyticsSummary()

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
        analytics = HealthAnalyticsEngine.analyze(recoveryScores.map { score in
            let factors = score.factors
            return HealthTrendSample(
                date: score.date,
                recovery: Double(score.overallScore),
                sleepHours: factors.sleepHours > 0 ? factors.sleepHours : nil,
                hydrationRate: factors.hydrationGoalML > 0 ? factors.hydrationPercent : nil,
                mood: factors.moodRating > 0 ? Double(factors.moodRating) : nil,
                habitRate: factors.habitsTotal > 0 ? factors.habitCompletionRate : nil
            )
        })
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

        if let delta = analytics.trendDelta {
            let improving = delta >= 0
            personalizedInsights.append(InsightFinding(
                id: "trend",
                icon: improving ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                title: improving ? "Recovery is trending up" : "Recovery has softened",
                detail: "Your recent average is \(String(format: "%.1f", abs(delta))) points \(improving ? "higher" : "lower") than the first half of this range.",
                sentiment: improving ? .positive : .attention
            ))
        }

        if let strongest = analytics.drivers.first, abs(strongest.coefficient) >= 0.2 {
            let positive = strongest.coefficient > 0
            personalizedInsights.append(InsightFinding(
                id: "driver-\(strongest.driver.id)",
                icon: strongest.driver.icon,
                title: "\(strongest.driver.rawValue) is your clearest signal",
                detail: "\(strongest.strengthLabel) \(positive ? "positive" : "inverse") association across \(strongest.sampleCount) logged days. This is a pattern, not proof of cause.",
                sentiment: positive ? .positive : .attention
            ))
        }

        if let consistency = analytics.consistencyScore {
            personalizedInsights.append(InsightFinding(
                id: "consistency",
                icon: "waveform.path",
                title: consistency >= 75 ? "Recovery is consistent" : "Your recovery varies",
                detail: "Stability score \(consistency)/100. \(consistency >= 75 ? "Your recent routine is producing relatively steady days." : "Compare sleep timing, hydration, and training load around the highest and lowest days.")",
                sentiment: consistency >= 75 ? .positive : .neutral
            ))
        }

        if !habitAdherence.isEmpty {
            personalizedInsights.append(InsightFinding(
                id: "habits",
                icon: "checkmark.seal.fill",
                title: "Habit adherence is \(Int(habitAdherenceRate * 100))%",
                detail: habitAdherenceRate >= 0.75 ? "Your micro-habits are becoming a reliable recovery foundation." : "Choose one small habit to make nearly automatic before adding more.",
                sentiment: habitAdherenceRate >= 0.75 ? .positive : .neutral
            ))
        }

        if personalizedInsights.isEmpty {
            personalizedInsights.append(InsightFinding(
                id: "more-data",
                icon: "plus.circle.fill",
                title: "Build your baseline",
                detail: "Log at least four recovery days to unlock trends and three matching factor days to reveal drivers.",
                sentiment: .neutral
            ))
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
        analytics.drivers.first { $0.driver == .sleep }?.coefficient
    }

    var habitAdherenceRate: Double {
        guard !habitAdherence.isEmpty else { return 0 }
        return habitAdherence.map(\.rate).reduce(0, +) / Double(habitAdherence.count)
    }

    var dataCoverage: Double {
        min(1, Double(recoveryScores.count) / Double(max(1, selectedRange.days)))
    }
}
