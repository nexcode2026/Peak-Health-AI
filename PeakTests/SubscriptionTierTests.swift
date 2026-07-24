import XCTest
@testable import Peak

final class SubscriptionTierTests: XCTestCase {
    func testFreeTierLimits() {
        XCTAssertEqual(SubscriptionTier.free.maxHabits, 3)
        XCTAssertEqual(SubscriptionTier.free.aiMessageLimit, 10)
        XCTAssertEqual(SubscriptionTier.free.historyDays, 14)
    }

    func testPremiumTierLimits() {
        XCTAssertEqual(SubscriptionTier.premium.aiMessageLimit, 500)
        XCTAssertEqual(SubscriptionTier.premium.maxHabits, Int.max)
    }

    func testProTierLimits() {
        XCTAssertEqual(SubscriptionTier.pro.aiMessageLimit, 2000)
    }

    func testImperialHydrationUsesUSFluidOunces() {
        let formatter = UnitFormatter(system: .imperial)

        XCTAssertEqual(formatter.waterUnitLabel, "fl oz")
        XCTAssertEqual(formatter.formatWater(236), "8 fl oz")
        XCTAssertEqual(formatter.formatWaterShort(2500), "84.5")
        XCTAssertEqual(formatter.formatWaterGoal(2500), "Goal 84.5 fl oz")
        XCTAssertFalse(formatter.formatWater(2500).localizedCaseInsensitiveContains("ml"))
        XCTAssertFalse(formatter.formatWater(2500).localizedCaseInsensitiveContains("cup"))
    }

    func testMetricHydrationRemainsMilliliters() {
        let formatter = UnitFormatter(system: .metric)

        XCTAssertEqual(formatter.formatWater(2500), "2500 ml")
        XCTAssertEqual(formatter.waterUnitLabel, "ml")
    }

    func testTodaySectionsHaveStableUniqueStorageKeys() {
        XCTAssertEqual(Set(TodaySection.defaultOrder).count, TodaySection.defaultOrder.count)
        XCTAssertTrue(TodaySection.defaultOrder.contains(.yourDay))
        XCTAssertTrue(TodaySection.defaultOrder.contains(.health))
        XCTAssertTrue(TodaySection.defaultOrder.contains(.cycle))
        XCTAssertFalse(TodaySection.defaultOrder.contains(.quickLog))
    }

    func testHealthMonitoringMetricsHaveStableUniqueStorageKeys() {
        XCTAssertEqual(Set(HealthMetricType.allCases).count, HealthMetricType.allCases.count)
        XCTAssertEqual(HealthMetricType.allCases.count, 9)
        XCTAssertTrue(HealthMetricType.allCases.contains(.bloodPressure))
        XCTAssertTrue(HealthMetricType.allCases.contains(.sleep))
    }

    func testMealAnalysisItemKeepsEditableNutritionValues() {
        let item = MealAnalysisItem(
            name: "Burrito Bowl",
            serving: "1 bowl",
            calories: 620,
            proteinG: 34,
            carbsG: 72,
            fatG: 21,
            fiberG: 11,
            sugarG: 7,
            saturatedFatG: 6,
            sodiumMg: 980,
            cholesterolMg: 65,
            ingredients: ["chicken", "black beans", "rice"],
            confidence: 0.82
        )

        XCTAssertEqual(item.calories, 620)
        XCTAssertEqual(item.proteinG, 34)
        XCTAssertEqual(item.fiberG, 11)
        XCTAssertEqual(item.sodiumMg, 980)
        XCTAssertEqual(item.ingredients, ["chicken", "black beans", "rice"])
        XCTAssertEqual(item.serving, "1 bowl")
    }

    func testTrainingTemplatesRoundTripWithoutLosingExercises() {
        let original = TrainingTemplate(
            name: "Lower Strength",
            workoutType: .strength,
            durationMinutes: 42.5,
            intensity: .high,
            exerciseDetails: "Squat · 4 × 6\nRomanian deadlift · 3 × 8",
            note: "Progress only with clean reps."
        )

        let decoded = TrainingTemplateStore.load(
            from: TrainingTemplateStore.encode([original])
        )

        XCTAssertEqual(decoded, [original])
        XCTAssertEqual(decoded.first?.durationMinutes, 42.5)
        XCTAssertTrue(decoded.first?.exerciseDetails.contains("Squat") == true)
    }

    func testWellnessStatusesExposeGuidance() {
        for status in WellnessStatus.allCases {
            XCTAssertFalse(status.emoji.isEmpty)
            XCTAssertFalse(status.guidance.isEmpty)
        }
    }
}
