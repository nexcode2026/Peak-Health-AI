import XCTest
@testable import Peak

final class RecoveryScoringServiceTests: XCTestCase {
    let service = RecoveryScoringService()

    func testPerfectRecoveryScore() {
        var factors = RecoveryFactors()
        factors.sleepHours = 8
        factors.sleepQuality = 0.9
        factors.hrvMS = 60
        factors.hrvTrend = 0.1
        factors.strainBalance = 0.85
        factors.hydrationML = 2500
        factors.hydrationGoalML = 2500
        factors.moodRating = 5
        factors.habitsCompleted = 5
        factors.habitsTotal = 5
        factors.habitStreakDays = 7

        let result = service.calculate(factors: factors)
        XCTAssertGreaterThanOrEqual(result.overallScore, 75)
        XCTAssertLessThanOrEqual(result.overallScore, 100)
    }

    func testLowRecoveryScore() {
        var factors = RecoveryFactors()
        factors.sleepHours = 4
        factors.sleepQuality = 0.3
        factors.hrvMS = 25
        factors.hrvTrend = -0.3
        factors.hydrationML = 500
        factors.hydrationGoalML = 2500
        factors.moodRating = 2
        factors.habitsCompleted = 0
        factors.habitsTotal = 5

        let result = service.calculate(factors: factors)
        XCTAssertLessThan(result.overallScore, 60)
    }

    func testEmptyFactorsReturnsModerateScore() {
        let result = service.calculate(factors: RecoveryFactors())
        XCTAssertGreaterThanOrEqual(result.overallScore, 40)
        XCTAssertLessThanOrEqual(result.overallScore, 60)
    }

    func testExplanationContainsLabel() {
        var factors = RecoveryFactors()
        factors.sleepHours = 7.5
        factors.hydrationML = 2000
        factors.hydrationGoalML = 2500

        let result = service.calculate(factors: factors)
        XCTAssertFalse(result.explanation.isEmpty)
        XCTAssertTrue(result.explanation.contains("Sleep") || result.explanation.contains("sleep"))
    }

    func testWeightsSumToOne() {
        let w = PeakConstants.RecoveryWeights.self
        let sum = w.sleep + w.hrvRestingHR + w.activityBalance + w.hydration + w.mood + w.habits
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    func testHealthAnalyticsFindsPositiveCorrelation() {
        let coefficient = HealthAnalyticsEngine.pearson(pairs: [
            (4, 42),
            (5, 50),
            (6, 63),
            (7, 72),
            (8, 88),
        ])

        XCTAssertNotNil(coefficient)
        XCTAssertGreaterThan(coefficient ?? 0, 0.95)
    }

    func testHealthAnalyticsFindsInverseCorrelation() {
        let coefficient = HealthAnalyticsEngine.pearson(pairs: [
            (1, 92),
            (2, 80),
            (3, 68),
            (4, 55),
            (5, 41),
        ])

        XCTAssertNotNil(coefficient)
        XCTAssertLessThan(coefficient ?? 0, -0.95)
    }

    func testHealthAnalyticsSummarizesTrendAndStreak() {
        let calendar = Calendar.current
        let start = Date().startOfDay
        let samples = (0..<6).map { offset in
            HealthTrendSample(
                date: calendar.date(byAdding: .day, value: offset, to: start)!,
                recovery: Double(50 + offset * 7),
                sleepHours: Double(5 + offset) * 0.5,
                hydrationRate: Double(offset) / 5,
                mood: Double(2 + min(offset, 3)),
                habitRate: Double(offset) / 5
            )
        }

        let summary = HealthAnalyticsEngine.analyze(samples)

        XCTAssertEqual(summary.loggingStreak, 6)
        XCTAssertGreaterThan(summary.trendDelta ?? 0, 0)
        XCTAssertEqual(summary.bestDay?.recovery, 85)
        XCTAssertFalse(summary.drivers.isEmpty)
    }

    func testPearsonRequiresEnoughVariableData() {
        XCTAssertNil(HealthAnalyticsEngine.pearson(pairs: [(1, 2), (2, 4)]))
        XCTAssertNil(HealthAnalyticsEngine.pearson(pairs: [(1, 2), (1, 3), (1, 4)]))
    }
}
