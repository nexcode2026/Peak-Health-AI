import Foundation
import SwiftData

// MARK: - Cached Health Snapshot (supplements live HealthKit queries)

@Model
final class HealthSnapshot {
    var id: UUID
    var date: Date
    var sleepHours: Double
    var sleepQuality: Double // 0-1 derived from stages
    var hrvMS: Double
    var restingHeartRate: Double
    var steps: Int
    var activeEnergyKcal: Double
    var workoutMinutes: Double
    var deepSleepMinutes: Double
    var remSleepMinutes: Double
    var syncedAt: Date

    init(
        date: Date = Date().startOfDay,
        sleepHours: Double = 0,
        sleepQuality: Double = 0,
        hrvMS: Double = 0,
        restingHeartRate: Double = 0,
        steps: Int = 0,
        activeEnergyKcal: Double = 0,
        workoutMinutes: Double = 0,
        deepSleepMinutes: Double = 0,
        remSleepMinutes: Double = 0
    ) {
        self.id = UUID()
        self.date = date.startOfDay
        self.sleepHours = sleepHours
        self.sleepQuality = sleepQuality
        self.hrvMS = hrvMS
        self.restingHeartRate = restingHeartRate
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.workoutMinutes = workoutMinutes
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.syncedAt = Date()
    }
}

struct HealthSnapshotExport: Codable {
    let date: Date
    let sleepHours: Double
    let hrvMS: Double
    let restingHeartRate: Double
    let steps: Int
    let activeEnergyKcal: Double
}