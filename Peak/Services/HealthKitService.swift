import Foundation
import HealthKit

// MARK: - HealthKit Service Protocol

protocol HealthKitServiceProtocol: Sendable {
    var isAvailable: Bool { get }
    var isAuthorized: Bool { get }
    func requestAuthorization() async throws
    func fetchDailyMetrics(for date: Date) async -> DailyHealthMetrics
    func enableBackgroundDelivery() async throws
    func fetchSleepSummary(days: Int) async -> [DailyHealthMetrics]
    func writeHydration(ml: Int, date: Date) async throws
}

struct DailyHealthMetrics: Sendable {
    var date: Date = Date().startOfDay
    var sleepHours: Double = 0
    var sleepQuality: Double = 0
    var deepSleepMinutes: Double = 0
    var remSleepMinutes: Double = 0
    var hrvMS: Double = 0
    var restingHeartRate: Double = 0
    var avgHeartRate: Double = 0
    var hrvTrend: Double = 0
    var steps: Int = 0
    var activeEnergyKcal: Double = 0
    var exerciseMinutes: Double = 0
    var workoutMinutes: Double = 0
    var dietaryCalories: Double = 0
    var dietaryProtein: Double = 0
    var bodyMassKg: Double = 0
    var heightCm: Double = 0
    var vo2Max: Double = 0
    var respiratoryRate: Double = 0
    var oxygenSaturation: Double = 0
    var bloodPressureSystolic: Double = 0
    var bloodPressureDiastolic: Double = 0
    var bodyTemperatureC: Double = 0
    var strainBalance: Double = 0.7
}

// MARK: - HealthKit Service Implementation

final class HealthKitService: HealthKitServiceProtocol, @unchecked Sendable {
    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let rhr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { types.insert(rhr) }
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(energy) }
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(exercise) }
        if let vo2 = HKQuantityType.quantityType(forIdentifier: .vo2Max) { types.insert(vo2) }
        if let resp = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) { types.insert(resp) }
        if let spo2 = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(spo2) }
        if let mass = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(mass) }
        if let height = HKQuantityType.quantityType(forIdentifier: .height) { types.insert(height) }
        if let systolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) { types.insert(systolic) }
        if let diastolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) { types.insert(diastolic) }
        if let temperature = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) { types.insert(temperature) }
        if let basalTemperature = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature) { types.insert(basalTemperature) }
        if let menstrualFlow = HKObjectType.categoryType(forIdentifier: .menstrualFlow) { types.insert(menstrualFlow) }
        if let cal = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) { types.insert(cal) }
        if let protein = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) { types.insert(protein) }
        if let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater) { types.insert(water) }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    private let writeTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        if let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater) { types.insert(water) }
        if let mindful = HKCategoryType.categoryType(forIdentifier: .mindfulSession) { types.insert(mindful) }
        return types
    }()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// HealthKit does not expose read-authorization status reliably — track whether we've requested access.
    var isAuthorized: Bool {
        guard isAvailable else { return false }
        return HealthKitAuthStorage.hasRequested
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw PeakError.healthKitNotAvailable }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        HealthKitAuthStorage.hasRequested = true
        PeakLogger.healthKit.info("HealthKit authorization requested")
    }

    func enableBackgroundDelivery() async throws {
        guard isAvailable else { return }
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount, .heartRateVariabilitySDNN, .restingHeartRate, .activeEnergyBurned
        ]
        for identifier in quantityTypes {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            try await store.enableBackgroundDelivery(for: type, frequency: .hourly)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            try await store.enableBackgroundDelivery(for: sleep, frequency: .daily)
        }
    }

    func fetchDailyMetrics(for date: Date) async -> DailyHealthMetrics {
        guard isAvailable else { return DailyHealthMetrics(date: date) }
        if !HealthKitAuthStorage.hasRequested {
            try? await requestAuthorization()
        }

        async let sleep = fetchSleep(for: date)
        async let hrv = fetchAverageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), date: date)
        async let rhr = fetchAverageQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()), date: date)
        async let avgHR = fetchAverageQuantity(.heartRate, unit: .count().unitDivided(by: .minute()), date: date)
        async let steps = fetchSumQuantity(.stepCount, unit: .count(), date: date)
        async let energy = fetchSumQuantity(.activeEnergyBurned, unit: .kilocalorie(), date: date)
        async let exercise = fetchSumQuantity(.appleExerciseTime, unit: .minute(), date: date)
        async let hrvTrend = fetchHRVTrend(around: date)
        async let dietaryCal = fetchSumQuantity(.dietaryEnergyConsumed, unit: .kilocalorie(), date: date)
        async let dietaryProt = fetchSumQuantity(.dietaryProtein, unit: .gram(), date: date)
        async let bodyMass = fetchLatestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        async let height = fetchLatestQuantity(.height, unit: .meterUnit(with: .centi))
        async let vo2 = fetchLatestQuantity(.vo2Max, unit: HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute())))
        async let respRate = fetchAverageQuantity(.respiratoryRate, unit: .count().unitDivided(by: .minute()), date: date)
        async let spo2 = fetchAverageQuantity(.oxygenSaturation, unit: .percent(), date: date)
        async let systolic = fetchAverageQuantity(.bloodPressureSystolic, unit: .millimeterOfMercury(), date: date)
        async let diastolic = fetchAverageQuantity(.bloodPressureDiastolic, unit: .millimeterOfMercury(), date: date)
        async let temperature = fetchAverageQuantity(.bodyTemperature, unit: .degreeCelsius(), date: date)
        async let workoutMins = fetchWorkoutMinutes(for: date)

        let sleepData = await sleep
        return DailyHealthMetrics(
            date: date,
            sleepHours: sleepData.hours,
            sleepQuality: sleepData.quality,
            deepSleepMinutes: sleepData.deep,
            remSleepMinutes: sleepData.rem,
            hrvMS: await hrv,
            restingHeartRate: await rhr,
            avgHeartRate: await avgHR,
            hrvTrend: await hrvTrend,
            steps: Int(await steps),
            activeEnergyKcal: await energy,
            exerciseMinutes: await exercise,
            workoutMinutes: await workoutMins,
            dietaryCalories: await dietaryCal,
            dietaryProtein: await dietaryProt,
            bodyMassKg: await bodyMass,
            heightCm: await height,
            vo2Max: await vo2,
            respiratoryRate: await respRate,
            oxygenSaturation: await spo2 * 100,
            bloodPressureSystolic: await systolic,
            bloodPressureDiastolic: await diastolic,
            bodyTemperatureC: await temperature,
            strainBalance: calculateStrainBalance(steps: Int(await steps), energy: await energy)
        )
    }

    func fetchSleepSummary(days: Int) async -> [DailyHealthMetrics] {
        var results: [DailyHealthMetrics] = []
        for offset in 0..<days {
            let date = Date().daysAgo(offset).startOfDay
            let metrics = await fetchDailyMetrics(for: date)
            results.append(metrics)
        }
        return results.reversed()
    }

    // MARK: - Private Queries

    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchWorkoutMinutes(for date: Date) async -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: date.startOfDay, end: date.endOfDay)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let total = (samples as? [HKWorkout])?.reduce(0.0) { $0 + $1.duration / 60 } ?? 0
                continuation.resume(returning: total)
            }
            store.execute(query)
        }
    }

    private func fetchSleep(for date: Date) async -> (hours: Double, quality: Double, deep: Double, rem: Double) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (0, 0, 0, 0)
        }

        let start = date.startOfDay
        let end = date.endOfDay
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    PeakLogger.healthKit.error("Sleep query failed: \(error.localizedDescription)")
                    continuation.resume(returning: (0, 0, 0, 0))
                    return
                }

                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: (0, 0, 0, 0))
                    return
                }

                var asleepMinutes: Double = 0
                var deepMinutes: Double = 0
                var remMinutes: Double = 0

                for sample in samples {
                    let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                         HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                         HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                         HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        asleepMinutes += minutes
                        if sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue { deepMinutes += minutes }
                        if sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue { remMinutes += minutes }
                    default: break
                    }
                }

                let hours = asleepMinutes / 60
                let quality = asleepMinutes > 0
                    ? min(1, (deepMinutes + remMinutes) / asleepMinutes * 1.5)
                    : 0
                continuation.resume(returning: (hours, quality, deepMinutes, remMinutes))
            }
            store.execute(query)
        }
    }

    private func fetchAverageQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: date.startOfDay, end: date.endOfDay)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, _ in
                let value = stats?.averageQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchSumQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: date.startOfDay, end: date.endOfDay)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchHRVTrend(around date: Date) async -> Double {
        let today = await fetchAverageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), date: date)
        let weekAgo = await fetchAverageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), date: date.daysAgo(7))
        guard today > 0, weekAgo > 0 else { return 0 }
        return ((today - weekAgo) / weekAgo).clamped(to: -1...1)
    }

    private func calculateStrainBalance(steps: Int, energy: Double) -> Double {
        let stepRatio = Double(steps) / Double(PeakConstants.Defaults.dailyStepsGoal)
        let energyRatio = energy / 500.0
        let load = (stepRatio + energyRatio) / 2
        // Optimal zone: 0.6–0.9 load
        if load >= 0.6 && load <= 0.9 { return 0.9 }
        if load < 0.6 { return 0.5 + load * 0.5 }
        return max(0.3, 1.0 - (load - 0.9) * 2)
    }

    /// Write hydration to HealthKit (optional sync)
    func writeHydration(ml: Int, date: Date = Date()) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(ml))
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await store.save(sample)
    }
}
