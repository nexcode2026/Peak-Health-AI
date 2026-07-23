import Foundation

/// Aggregated daily metrics for drill-down detail screens.
struct DailyHealthSnapshot: Sendable {
    var sleepHours: Double = 0
    var sleepQuality: Int?
    var deepSleepHours: Double = 0
    var remSleepHours: Double = 0
    var hrvMs: Double?
    var restingHeartRate: Double?
    var averageHeartRate: Double?
    var respiratoryRate: Double?
    var oxygenSaturation: Double?
    var bloodPressureSystolic: Double?
    var bloodPressureDiastolic: Double?
    var bodyTemperatureC: Double?
    var bodyMassKg: Double?
    var heightCm: Double?
    var steps: Int = 0
    var hydrationMl: Double = 0
    var hydrationGoalMl: Double = 2500
    var moodScore: Int?
    var habitCompletionRate: Double = 0
    var exerciseMinutes: Double = 0
    var distanceKm: Double = 0
    var vo2Max: Double?
    var caloriesConsumed: Double = 0
    var calorieGoal: Double = 2200
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0

    static func build(
        metrics: DailyHealthMetrics?,
        hydrationML: Int,
        hydrationGoal: Int,
        calories: Int,
        calorieGoal: Int,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        habitsCompleted: Int,
        habitsTotal: Int,
        moodRating: Int? = nil
    ) -> DailyHealthSnapshot {
        var snap = DailyHealthSnapshot()
        if let m = metrics {
            snap.sleepHours = m.sleepHours
            snap.sleepQuality = m.sleepQuality > 0 ? Int(m.sleepQuality * 10) : nil
            snap.deepSleepHours = m.deepSleepMinutes / 60
            snap.remSleepHours = m.remSleepMinutes / 60
            snap.hrvMs = m.hrvMS > 0 ? m.hrvMS : nil
            snap.restingHeartRate = m.restingHeartRate > 0 ? m.restingHeartRate : nil
            snap.averageHeartRate = m.avgHeartRate > 0 ? m.avgHeartRate : nil
            snap.respiratoryRate = m.respiratoryRate > 0 ? m.respiratoryRate : nil
            snap.oxygenSaturation = m.oxygenSaturation > 0 ? m.oxygenSaturation : nil
            snap.bloodPressureSystolic = m.bloodPressureSystolic > 0 ? m.bloodPressureSystolic : nil
            snap.bloodPressureDiastolic = m.bloodPressureDiastolic > 0 ? m.bloodPressureDiastolic : nil
            snap.bodyTemperatureC = m.bodyTemperatureC > 0 ? m.bodyTemperatureC : nil
            snap.bodyMassKg = m.bodyMassKg > 0 ? m.bodyMassKg : nil
            snap.heightCm = m.heightCm > 0 ? m.heightCm : nil
            snap.steps = m.steps
            snap.exerciseMinutes = m.exerciseMinutes
            snap.vo2Max = m.vo2Max > 0 ? m.vo2Max : nil
            snap.proteinGrams = m.dietaryProtein > 0 ? m.dietaryProtein : protein
            snap.caloriesConsumed = m.dietaryCalories > 0 ? m.dietaryCalories : Double(calories)
            snap.carbsGrams = carbs
            snap.fatGrams = fat
        } else {
            snap.caloriesConsumed = Double(calories)
            snap.proteinGrams = protein
            snap.carbsGrams = carbs
            snap.fatGrams = fat
        }
        snap.hydrationMl = Double(hydrationML)
        snap.hydrationGoalMl = Double(hydrationGoal)
        snap.calorieGoal = Double(calorieGoal)
        snap.moodScore = moodRating
        snap.habitCompletionRate = habitsTotal > 0 ? Double(habitsCompleted) / Double(habitsTotal) : 0
        return snap
    }
}
