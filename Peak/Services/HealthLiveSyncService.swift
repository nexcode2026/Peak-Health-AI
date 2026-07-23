import Foundation
import HealthKit
import Observation
import SwiftUI

@Observable
@MainActor
final class HealthLiveSyncService {
    private let healthStore = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    private var isObserving = false

    var isLive = false
    var lastSyncDate: Date?
    var connectedSources: [String] = []
    var hasAppleWatch = false
    var liveSteps: Int = 0
    var liveHRV: Double?
    var liveHeartRate: Double?
    var liveActiveCalories: Double = 0
    var liveSleepHours: Double = 0
    var syncPulse = false

    var onDataUpdated: (() -> Void)?

    private let observedTypes: [HKQuantityTypeIdentifier] = [
        .stepCount,
        .heartRate,
        .activeEnergyBurned,
        .restingHeartRate,
        .heartRateVariabilitySDNN,
        .oxygenSaturation,
        .respiratoryRate
    ]

    func startObserving() async {
        guard HKHealthStore.isHealthDataAvailable(), !isObserving else { return }
        isObserving = true

        await refreshSources()
        await refreshLiveMetrics()

        for identifier in observedTypes {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            attachObserver(for: type)
            try? await healthStore.enableBackgroundDelivery(for: type, frequency: .immediate)
        }

        let sleepType = HKCategoryType(.sleepAnalysis)
        attachObserver(for: sleepType)
        try? await healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate)

        isLive = true
        lastSyncDate = .now
    }

    func stopObserving() {
        for query in observers {
            healthStore.stop(query)
        }
        observers.removeAll()
        isObserving = false
        isLive = false
    }

    func manualRefresh() async {
        await refreshSources()
        await refreshLiveMetrics()
        lastSyncDate = .now
        withAnimation(Animation.spring(response: 0.4)) {
            syncPulse.toggle()
        }
    }

    private func handleUpdate() async {
        await refreshLiveMetrics()
        lastSyncDate = .now
        withAnimation(Animation.spring(response: 0.35)) {
            syncPulse.toggle()
        }
        onDataUpdated?()
    }

    private func refreshSources() async {
        var sources: Set<String> = []
        var watchFound = false

        let types: [HKSampleType] = [
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRate),
            HKCategoryType(.sleepAnalysis)
        ]

        for type in types {
            let srcs: [HKSource] = await withCheckedContinuation { (cont: CheckedContinuation<[HKSource], Never>) in
                let query = HKSourceQuery(sampleType: type, samplePredicate: nil) { (_, srcSet, error) in
                    if let srcSet = srcSet {
                        cont.resume(returning: Array(srcSet))
                    } else {
                        cont.resume(returning: [])
                    }
                }
                self.healthStore.execute(query)
            }

            for src in srcs {
                sources.insert(src.name)
                if src.name.localizedCaseInsensitiveContains("Watch") ||
                    src.bundleIdentifier.localizedCaseInsensitiveContains("watch") {
                    watchFound = true
                }
            }
        }

        connectedSources = Array(sources).sorted()
        hasAppleWatch = watchFound
    }

    private func attachObserver(for sampleType: HKSampleType) {
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completion, error in
            guard error == nil else {
                completion()
                return
            }
            Task { @MainActor in
                await self?.handleUpdate()
                completion()
            }
        }
        observers.append(query)
        healthStore.execute(query)
    }

    private func refreshLiveMetrics() async {
        liveSteps = Int(await fetchTodaySum(.stepCount))
        liveActiveCalories = await fetchTodaySum(.activeEnergyBurned)
        liveHeartRate = await fetchLatest(.heartRate)
        liveHRV = await fetchLatest(.heartRateVariabilitySDNN)
        liveSleepHours = await fetchLastNightSleepHours()
    }

    private func fetchLastNightSleepHours() async -> Double {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let end = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -18, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    cont.resume(returning: 0)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let hours = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600
                cont.resume(returning: hours)
            }
            healthStore.execute(q)
        }
    }

    private func fetchTodaySum(_ id: HKQuantityTypeIdentifier) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let unit = unitFor(id)
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(q)
        }
    }

    private func fetchLatest(_ id: HKQuantityTypeIdentifier) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let unit = unitFor(id)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            healthStore.execute(q)
        }
    }

    private func unitFor(_ id: HKQuantityTypeIdentifier) -> HKUnit {
        switch id {
        case .stepCount:
            return .count()
        case .heartRate:
            // Heart rate is typically stored as count per minute
            return HKUnit.count().unitDivided(by: .minute())
        case .activeEnergyBurned:
            return .kilocalorie()
        case .restingHeartRate:
            return HKUnit.count().unitDivided(by: .minute())
        case .heartRateVariabilitySDNN:
            return .secondUnit(with: .milli)
        case .oxygenSaturation:
            // Stored as a percentage 0.0 - 1.0; use percent unit
            return .percent()
        case .respiratoryRate:
            // Breaths per minute
            return HKUnit.count().unitDivided(by: .minute())
        default:
            // Fallback to a dimensionless count
            return .count()
        }
    }
}
