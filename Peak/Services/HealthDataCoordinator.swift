import Foundation
import SwiftData

/// Single source of truth for health metrics — merges live observer data with HealthKit queries
/// so every view shows consistent numbers.
@MainActor
@Observable
final class HealthDataCoordinator {
    private let healthKit: any HealthKitServiceProtocol
    private let liveSync: HealthLiveSyncService

    private(set) var todayMetrics: DailyHealthMetrics = DailyHealthMetrics()
    private(set) var lastRefreshed: Date?
    private(set) var authorizationStatus: HealthAuthorizationStatus = .notDetermined

    init(healthKit: any HealthKitServiceProtocol, liveSync: HealthLiveSyncService) {
        self.healthKit = healthKit
        self.liveSync = liveSync
    }

    // MARK: - Unified accessors (prefer freshest live data, fall back to daily query)

    var steps: Int {
        max(liveSync.liveSteps, todayMetrics.steps)
    }

    var activeCalories: Double {
        max(liveSync.liveActiveCalories, todayMetrics.activeEnergyKcal)
    }

    var sleepHours: Double {
        max(liveSync.liveSleepHours, todayMetrics.sleepHours)
    }

    var hrvMS: Double {
        liveSync.liveHRV ?? todayMetrics.hrvMS
    }

    var restingHeartRate: Double {
        liveSync.liveHeartRate ?? todayMetrics.restingHeartRate
    }

    var strainBalance: Double {
        todayMetrics.strainBalance
    }

    var strainPercent: Int {
        Int(strainBalance * 100)
    }

    // MARK: - Refresh

    func refresh(modelContext: ModelContext, date: Date = Date().startOfDay) async {
        authorizationStatus = resolveAuthorizationStatus()

        guard healthKit.isAvailable else {
            todayMetrics = DailyHealthMetrics(date: date)
            return
        }

        // Never present Health authorization during app bootstrap. The user chooses
        // this explicitly during onboarding or from a Connect Health action.
        guard authorizationStatus == .authorized else {
            todayMetrics = DailyHealthMetrics(date: date)
            lastRefreshed = .now
            return
        }

        let queried = await healthKit.fetchDailyMetrics(for: date)
        // Live observers only describe the current day. Mixing those samples into
        // a historical date makes old rings appear to contain today's activity.
        todayMetrics = date.isToday ? merge(queried: queried, live: liveSync, date: date) : queried
        lastRefreshed = .now

        await persistSnapshot(modelContext: modelContext, metrics: todayMetrics)
    }

    func mergedMetrics() -> DailyHealthMetrics {
        var m = todayMetrics
        m.steps = steps
        m.activeEnergyKcal = activeCalories
        m.sleepHours = sleepHours
        if let hrv = liveSync.liveHRV, hrv > 0 { m.hrvMS = hrv }
        if let hr = liveSync.liveHeartRate, hr > 0 { m.restingHeartRate = hr }
        return m
    }

    // MARK: - Private

    private func resolveAuthorizationStatus() -> HealthAuthorizationStatus {
        guard healthKit.isAvailable else { return .unavailable }
        if HealthKitAuthStorage.hasRequested { return .authorized }
        return .notDetermined
    }

    private func merge(
        queried: DailyHealthMetrics,
        live: HealthLiveSyncService,
        date: Date
    ) -> DailyHealthMetrics {
        var merged = queried
        merged.date = date
        merged.steps = max(live.liveSteps, queried.steps)
        merged.activeEnergyKcal = max(live.liveActiveCalories, queried.activeEnergyKcal)
        merged.sleepHours = max(live.liveSleepHours, queried.sleepHours)
        if let hrv = live.liveHRV, hrv > 0 { merged.hrvMS = hrv }
        if let hr = live.liveHeartRate, hr > 0 {
            merged.restingHeartRate = hr
            merged.avgHeartRate = hr
        }
        merged.strainBalance = queried.strainBalance
        return merged
    }

    private func persistSnapshot(modelContext: ModelContext, metrics: DailyHealthMetrics) async {
        let today = metrics.date.startOfDay
        let descriptor = FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate { $0.date == today }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.sleepHours = metrics.sleepHours
            existing.sleepQuality = metrics.sleepQuality
            existing.hrvMS = metrics.hrvMS
            existing.restingHeartRate = metrics.restingHeartRate
            existing.steps = metrics.steps
            existing.activeEnergyKcal = metrics.activeEnergyKcal
            existing.workoutMinutes = metrics.workoutMinutes
            existing.deepSleepMinutes = metrics.deepSleepMinutes
            existing.remSleepMinutes = metrics.remSleepMinutes
            existing.syncedAt = .now
        } else {
            let snapshot = HealthSnapshot(
                date: today,
                sleepHours: metrics.sleepHours,
                sleepQuality: metrics.sleepQuality,
                hrvMS: metrics.hrvMS,
                restingHeartRate: metrics.restingHeartRate,
                steps: metrics.steps,
                activeEnergyKcal: metrics.activeEnergyKcal,
                workoutMinutes: metrics.workoutMinutes,
                deepSleepMinutes: metrics.deepSleepMinutes,
                remSleepMinutes: metrics.remSleepMinutes
            )
            modelContext.insert(snapshot)
        }
        try? modelContext.save()
    }
}

enum HealthAuthorizationStatus: Sendable {
    case unavailable
    case notDetermined
    case authorized
    case denied

    var displayMessage: String {
        switch self {
        case .unavailable: return "Apple Health is not available on this device."
        case .notDetermined: return "Connect Apple Health to unlock recovery insights."
        case .authorized: return "Apple Health connected"
        case .denied: return "Enable Health access in Settings → Health → Peak."
        }
    }
}
