import CoreLocation
import CoreMotion
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class WorkoutTrackingService: NSObject {
    enum State: Equatable {
        case idle
        case tracking
        case paused
    }

    private let locationManager = CLLocationManager()
    private let pedometer = CMPedometer()
    private var motionActivityManager: CMMotionActivityManager?

    private(set) var state: State = .idle
    private(set) var workoutType: WorkoutType = .walking
    private(set) var elapsedSeconds: TimeInterval = 0
    private(set) var distanceKm: Double = 0
    private(set) var steps: Int = 0
    private(set) var currentPaceMinPerKm: Double?
    private(set) var locations: [CLLocation] = []
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var timer: Timer?
    private var startDate: Date?
    private var lastLocation: CLLocation?
    private var pedometerStartSteps: Int?

    var isLocationAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return true
        default: return false
        }
    }

    var isMotionAvailable: Bool {
        CMPedometer.isStepCountingAvailable() || CMMotionActivityManager.isActivityAvailable()
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }

    func start(workoutType: WorkoutType) {
        guard state == .idle else { return }
        self.workoutType = workoutType
        state = .tracking
        startDate = .now
        elapsedSeconds = 0
        distanceKm = 0
        steps = 0
        locations = []
        lastLocation = nil
        currentPaceMinPerKm = nil

        locationManager.startUpdatingLocation()
        startPedometer()
        startTimer()
        PeakLogger.general.info("Workout tracking started: \(workoutType.rawValue)")
    }

    func pause() {
        guard state == .tracking else { return }
        state = .paused
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        guard state == .paused else { return }
        state = .tracking
        locationManager.startUpdatingLocation()
        startPedometer()
        startTimer()
    }

    func stop(modelContext: ModelContext) -> WorkoutLog? {
        guard state != .idle, let startDate else { return nil }

        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        timer?.invalidate()
        timer = nil

        let durationMinutes = max(1, elapsedSeconds / 60)
        let calories = Double(workoutType.kcalPerMinute) * durationMinutes

        let log = WorkoutLog(
            name: workoutType.displayName,
            workoutType: workoutType,
            durationMinutes: durationMinutes,
            caloriesBurned: calories,
            distanceKm: distanceKm,
            intensity: .moderate,
            note: locations.count > 1 ? "GPS tracked (\(locations.count) points)" : nil,
            date: startDate
        )
        modelContext.insert(log)
        try? modelContext.save()
        AchievementService.evaluateAll(modelContext: modelContext)

        reset()
        PeakHaptics.success()
        return log
    }

    func cancel() {
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        timer?.invalidate()
        timer = nil
        reset()
    }

    private func reset() {
        state = .idle
        startDate = nil
        elapsedSeconds = 0
        distanceKm = 0
        steps = 0
        locations = []
        lastLocation = nil
        currentPaceMinPerKm = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startDate else { return }
                self.elapsedSeconds = Date().timeIntervalSince(start)
            }
        }
    }

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable(), let startDate else { return }
        pedometer.startUpdates(from: startDate) { [weak self] data, error in
            guard error == nil, let data else { return }
            Task { @MainActor in
                self?.steps = data.numberOfSteps.intValue
            }
        }
    }

    private func appendLocation(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 50 else { return }
        locations.append(location)

        if let last = lastLocation {
            let delta = location.distance(from: last) / 1000
            if delta > 0, delta < 0.5 {
                distanceKm += delta
                if elapsedSeconds > 0, distanceKm > 0 {
                    currentPaceMinPerKm = (elapsedSeconds / 60) / distanceKm
                }
            }
        }
        lastLocation = location
    }
}

extension WorkoutTrackingService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            appendLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        PeakLogger.general.error("Location error: \(error.localizedDescription)")
    }
}