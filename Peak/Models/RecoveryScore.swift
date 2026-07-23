import Foundation
import SwiftData

// MARK: - Daily Recovery Score

@Model
final class RecoveryScore {
    var id: UUID = UUID()
    var date: Date = Date()
    var overallScore: Int = 0
    var sleepScore: Double = 0
    var hrvScore: Double = 0
    var activityScore: Double = 0
    var hydrationScore: Double = 0
    var moodScore: Double = 0
    var habitScore: Double = 0
    var explanation: String = ""
    var factorsJSON: String = "{}" // JSON-encoded RecoveryFactors
    var createdAt: Date = Date()

    init(
        date: Date = Date().startOfDay,
        overallScore: Int = 0,
        sleepScore: Double = 0,
        hrvScore: Double = 0,
        activityScore: Double = 0,
        hydrationScore: Double = 0,
        moodScore: Double = 0,
        habitScore: Double = 0,
        explanation: String = "",
        factors: RecoveryFactors = RecoveryFactors()
    ) {
        self.id = UUID()
        self.date = date.startOfDay
        self.overallScore = overallScore.clamped(to: 0...100)
        self.sleepScore = sleepScore
        self.hrvScore = hrvScore
        self.activityScore = activityScore
        self.hydrationScore = hydrationScore
        self.moodScore = moodScore
        self.habitScore = habitScore
        self.explanation = explanation
        self.factorsJSON = (try? String(data: JSONEncoder().encode(factors), encoding: .utf8)) ?? "{}"
        self.createdAt = Date()
    }

    @Transient
    var factors: RecoveryFactors {
        guard let data = factorsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(RecoveryFactors.self, from: data) else {
            return RecoveryFactors()
        }
        return decoded
    }
}

// MARK: - Recovery Factor Details (Codable for export + AI context)

struct RecoveryFactors: Codable, Sendable {
    var sleepHours: Double = 0
    var sleepQuality: Double = 0 // 0-1
    var hrvMS: Double = 0
    var restingHR: Double = 0
    var hrvTrend: Double = 0 // -1 to 1
    var activeEnergyKcal: Double = 0
    var steps: Int = 0
    var strainBalance: Double = 0 // 0-1
    var hydrationML: Int = 0
    var hydrationGoalML: Int = PeakConstants.Defaults.dailyWaterML
    var moodRating: Int = 0 // 1-5
    var habitsCompleted: Int = 0
    var habitsTotal: Int = 0
    var habitStreakDays: Int = 0

    var hydrationPercent: Double {
        guard hydrationGoalML > 0 else { return 0 }
        return Double(hydrationML) / Double(hydrationGoalML)
    }

    var habitCompletionRate: Double {
        guard habitsTotal > 0 else { return 0 }
        return Double(habitsCompleted) / Double(habitsTotal)
    }
}

struct RecoveryScoreExport: Codable {
    let date: Date
    let overallScore: Int
    let sleepScore: Double
    let hrvScore: Double
    let activityScore: Double
    let hydrationScore: Double
    let moodScore: Double
    let habitScore: Double
    let explanation: String
}
