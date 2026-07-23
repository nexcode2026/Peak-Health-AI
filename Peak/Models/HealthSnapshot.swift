import Foundation
import SwiftData

// MARK: - Cached Health Snapshot (supplements live HealthKit queries)

@Model
final class HealthSnapshot {
    var id: UUID = UUID()
    var date: Date = Date()
    var sleepHours: Double = 0
    var sleepQuality: Double = 0 // 0-1 derived from stages
    var hrvMS: Double = 0
    var restingHeartRate: Double = 0
    var steps: Int = 0
    var activeEnergyKcal: Double = 0
    var workoutMinutes: Double = 0
    var deepSleepMinutes: Double = 0
    var remSleepMinutes: Double = 0
    var syncedAt: Date = Date()

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
