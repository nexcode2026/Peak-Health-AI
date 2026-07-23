import Foundation

// MARK: - Recovery Scoring Protocol

protocol RecoveryScoringServiceProtocol: Sendable {
    func calculate(factors: RecoveryFactors) -> RecoveryResult
    func explain(score: RecoveryResult, factors: RecoveryFactors) -> String
}

struct RecoveryResult: Sendable {
    let overallScore: Int
    let sleepScore: Double
    let hrvScore: Double
    let activityScore: Double
    let hydrationScore: Double
    let moodScore: Double
    let habitScore: Double
    let explanation: String
}

// MARK: - Recovery Scoring Engine
// Weighted composite 0–100. See PeakConstants.RecoveryWeights for documented assumptions.

final class RecoveryScoringService: RecoveryScoringServiceProtocol {
    private let weights = PeakConstants.RecoveryWeights.self

    func calculate(factors: RecoveryFactors) -> RecoveryResult {
        let sleep = scoreSleep(factors)
        let hrv = scoreHRV(factors)
        let activity = scoreActivity(factors)
        let hydration = scoreHydration(factors)
        let mood = scoreMood(factors)
        let habits = scoreHabits(factors)

        let composite = sleep * weights.sleep
            + hrv * weights.hrvRestingHR
            + activity * weights.activityBalance
            + hydration * weights.hydration
            + mood * weights.mood
            + habits * weights.habits

        let overall = Int(composite.rounded()).clamped(to: 0...100)

        var result = RecoveryResult(
            overallScore: overall,
            sleepScore: sleep,
            hrvScore: hrv,
            activityScore: activity,
            hydrationScore: hydration,
            moodScore: mood,
            habitScore: habits,
            explanation: ""
        )
        result = RecoveryResult(
            overallScore: overall,
            sleepScore: sleep,
            hrvScore: hrv,
            activityScore: activity,
            hydrationScore: hydration,
            moodScore: mood,
            habitScore: habits,
            explanation: explain(score: result, factors: factors)
        )
        return result
    }

    func explain(score: RecoveryResult, factors: RecoveryFactors) -> String {
        var parts: [String] = []

        if factors.sleepHours > 0 {
            let sleepNote = factors.sleepHours >= 7 ? "solid" : "below target"
            parts.append("Sleep: \(factors.sleepHours.formattedOneDecimal)h (\(sleepNote))")
        } else {
            parts.append("Sleep: no data yet")
        }

        if factors.hrvMS > 0 {
            let trend = factors.hrvTrend > 0.1 ? "improving" : (factors.hrvTrend < -0.1 ? "declining" : "stable")
            parts.append("HRV: \(Int(factors.hrvMS))ms (\(trend))")
        }

        if factors.hydrationML > 0 {
            let pct = Int(factors.hydrationPercent * 100)
            parts.append("Hydration: \(pct)% of goal")
        }

        if factors.habitsTotal > 0 {
            parts.append("Habits: \(factors.habitsCompleted)/\(factors.habitsTotal) completed")
        }

        if factors.moodRating > 0 {
            parts.append("Mood: \(factors.moodRating)/5")
        }

        let label = PeakTheme.recoveryLabel(for: score.overallScore)
        return "\(label) — \(parts.joined(separator: ". "))."
    }

    // MARK: - Component Scorers (0–100)

    private func scoreSleep(_ f: RecoveryFactors) -> Double {
        guard f.sleepHours > 0 else { return 50 }
        let durationScore: Double
        if f.sleepHours >= 7 && f.sleepHours <= 9 {
            durationScore = 100
        } else if f.sleepHours >= 6 {
            durationScore = 70 + (f.sleepHours - 6) * 30
        } else {
            durationScore = max(20, f.sleepHours / 6 * 70)
        }
        let qualityBonus = f.sleepQuality * 20
        return min(100, durationScore * 0.8 + qualityBonus)
    }

    private func scoreHRV(_ f: RecoveryFactors) -> Double {
        guard f.hrvMS > 0 else { return 50 }
        // Normalize HRV: typical range 20-80ms for general population
        let base = ((f.hrvMS - 20) / 60 * 80).clamped(to: 20...90)
        let trendBonus = f.hrvTrend * 10
        return min(100, base + trendBonus)
    }

    private func scoreActivity(_ f: RecoveryFactors) -> Double {
        guard f.steps > 0 || f.activeEnergyKcal > 0 else { return 50 }
        // Balance: moderate activity is optimal; overtraining reduces score
        let strain = f.strainBalance
        if strain > 0 {
            return strain * 100
        }
        let stepScore = min(100, Double(f.steps) / Double(PeakConstants.Defaults.dailyStepsGoal) * 85)
        return stepScore
    }

    private func scoreHydration(_ f: RecoveryFactors) -> Double {
        guard f.hydrationGoalML > 0 else { return 50 }
        let pct = f.hydrationPercent
        if pct >= 1.0 { return 100 }
        if pct >= 0.8 { return 80 + (pct - 0.8) * 100 }
        return max(20, pct * 100)
    }

    private func scoreMood(_ f: RecoveryFactors) -> Double {
        guard f.moodRating > 0 else { return 50 }
        return Double(f.moodRating) / 5.0 * 100
    }

    private func scoreHabits(_ f: RecoveryFactors) -> Double {
        guard f.habitsTotal > 0 else { return 50 }
        let rate = f.habitCompletionRate
        let streakBonus = min(15, Double(f.habitStreakDays) * 2)
        return min(100, rate * 85 + streakBonus)
    }
}