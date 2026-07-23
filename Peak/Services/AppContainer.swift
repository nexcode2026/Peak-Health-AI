import Foundation
import StoreKit
import SwiftData
import SwiftUI

// MARK: - Dependency Injection Container

@MainActor
@Observable
final class AppContainer {
    let healthKit: any HealthKitServiceProtocol
    let recoveryScoring: any RecoveryScoringServiceProtocol
    let auth: any AuthServiceProtocol
    let subscription: any SubscriptionServiceProtocol
    let ai: any AIServiceProtocol
    let notifications: any NotificationServiceProtocol
    let export: any ExportServiceProtocol
    let biometrics: any BiometricAuthServiceProtocol
    let keychain: KeychainService
    let liveSync: HealthLiveSyncService
    let healthData: HealthDataCoordinator
    let cloudKitSync: CloudKitSyncService
    private var workoutTrackerStorage: WorkoutTrackingService?

    /// Badge unlocked during the latest evaluation — consumed by views for celebration UI.
    var pendingAchievementUnlock: Achievement?
    var workoutTracker: WorkoutTrackingService {
        if let workoutTrackerStorage { return workoutTrackerStorage }
        let service = WorkoutTrackingService()
        workoutTrackerStorage = service
        return service
    }

    var currentTier: SubscriptionTier = .free
    var subscriptionStatus: SubscriptionStatus = .none
    var isUnlocked: Bool = true
    var syncStatus: SyncStatus = .idle

    init(
        healthKit: (any HealthKitServiceProtocol)? = nil,
        recoveryScoring: (any RecoveryScoringServiceProtocol)? = nil,
        auth: (any AuthServiceProtocol)? = nil,
        subscription: (any SubscriptionServiceProtocol)? = nil,
        ai: (any AIServiceProtocol)? = nil,
        notifications: (any NotificationServiceProtocol)? = nil,
        export: (any ExportServiceProtocol)? = nil,
        biometrics: (any BiometricAuthServiceProtocol)? = nil
    ) {
        self.keychain = KeychainService()
        self.liveSync = HealthLiveSyncService()
        let hk = healthKit ?? HealthKitService()
        self.healthKit = hk
        self.healthData = HealthDataCoordinator(healthKit: hk, liveSync: self.liveSync)
        self.cloudKitSync = CloudKitSyncService()
        self.recoveryScoring = recoveryScoring ?? RecoveryScoringService()
        self.auth = auth ?? AuthService(keychain: self.keychain)
        self.subscription = subscription ?? SubscriptionService()
        self.ai = ai ?? AIService(keychain: self.keychain)
        self.notifications = notifications ?? NotificationService()
        self.export = export ?? ExportService()
        self.biometrics = biometrics ?? BiometricAuthService()
    }

    func configure(modelContext: ModelContext) async {
        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            notifications.configure(profile: profile)
        }

        await healthData.refresh(modelContext: modelContext)
        evaluateAchievements(modelContext: modelContext)

        liveSync.onDataUpdated = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.healthData.refresh(modelContext: modelContext)
                await self.calculateTodayRecovery(modelContext: modelContext)
                self.evaluateAchievements(modelContext: modelContext)
            }
        }
        // StoreKit and CloudKit can take an indeterminate amount of time on a new
        // simulator, offline device, or signed-out iCloud account. They should
        // enrich the session after launch, never hold the account gate hostage.
        Task { [weak self] in
            guard let self else { return }
            await self.subscription.loadProducts()
            await self.subscription.updateSubscriptionStatus()
            self.currentTier = self.subscription.currentTier
            self.subscriptionStatus = self.subscription.status
            await self.cloudKitSync.refreshStatus()
        }
    }

    func evaluateAchievements(modelContext: ModelContext) {
        let unlocked = AchievementService.evaluateAll(modelContext: modelContext)
        if let first = unlocked.first {
            pendingAchievementUnlock = first
        }
    }

    func startHealthLiveSync() async {
        guard healthKit.isAvailable else { return }
        if !HealthKitAuthStorage.hasRequested {
            try? await healthKit.requestAuthorization()
        }
        if !liveSync.isLive {
            await liveSync.startObserving()
        }
    }

    func refreshAll(modelContext: ModelContext) async {
        syncStatus = .syncing
        do {
            if healthKit.isAvailable {
                try await healthKit.enableBackgroundDelivery()
                await startHealthLiveSync()
            }
            await healthData.refresh(modelContext: modelContext)
            await calculateTodayRecovery(modelContext: modelContext)
            evaluateAchievements(modelContext: modelContext)
            await cloudKitSync.refreshStatus()
            syncStatus = .synced
        } catch {
            PeakLogger.general.error("Refresh failed: \(error.localizedDescription)")
            syncStatus = .failed(error.localizedDescription)
        }
    }

    func calculateTodayRecovery(modelContext: ModelContext) async {
        let factors = await gatherRecoveryFactors(modelContext: modelContext)
        let result = recoveryScoring.calculate(factors: factors)

        let today = Date().startOfDay
        let descriptor = FetchDescriptor<RecoveryScore>(
            predicate: #Predicate { $0.date == today }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.overallScore = result.overallScore
            existing.sleepScore = result.sleepScore
            existing.hrvScore = result.hrvScore
            existing.activityScore = result.activityScore
            existing.hydrationScore = result.hydrationScore
            existing.moodScore = result.moodScore
            existing.habitScore = result.habitScore
            existing.explanation = result.explanation
            existing.factorsJSON = (try? String(data: JSONEncoder().encode(factors), encoding: .utf8)) ?? "{}"
        } else {
            let score = RecoveryScore(
                date: today,
                overallScore: result.overallScore,
                sleepScore: result.sleepScore,
                hrvScore: result.hrvScore,
                activityScore: result.activityScore,
                hydrationScore: result.hydrationScore,
                moodScore: result.moodScore,
                habitScore: result.habitScore,
                explanation: result.explanation,
                factors: factors
            )
            modelContext.insert(score)
        }
        try? modelContext.save()
    }

    private func gatherRecoveryFactors(modelContext: ModelContext) async -> RecoveryFactors {
        var factors = RecoveryFactors()
        let today = Date().startOfDay

        let health = healthData.mergedMetrics()
        factors.sleepHours = health.sleepHours
        factors.sleepQuality = health.sleepQuality
        factors.hrvMS = health.hrvMS
        factors.restingHR = health.restingHeartRate
        factors.steps = health.steps
        factors.activeEnergyKcal = health.activeEnergyKcal
        factors.hrvTrend = health.hrvTrend
        factors.strainBalance = health.strainBalance

        let hydrationDescriptor = FetchDescriptor<HydrationLog>(
            predicate: #Predicate { $0.date >= today }
        )
        if let logs = try? modelContext.fetch(hydrationDescriptor) {
            factors.hydrationML = logs.reduce(0) { $0 + $1.amountML }
        }

        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            factors.hydrationGoalML = profile.dailyWaterGoalML
        }

        let moodDescriptor = FetchDescriptor<MoodReflection>(
            predicate: #Predicate { $0.date >= today },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let mood = try? modelContext.fetch(moodDescriptor).first {
            factors.moodRating = mood.moodRating
        }

        let habits = try? modelContext.fetch(FetchDescriptor<HabitDefinition>(
            predicate: #Predicate { $0.isActive }
        ))
        let habitLogs = try? modelContext.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.date == today && $0.completed }
        ))
        factors.habitsTotal = habits?.count ?? 0
        factors.habitsCompleted = habitLogs?.count ?? 0

        return factors
    }
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case failed(String)
}

// MARK: - Environment Key

private struct AppContainerKey: EnvironmentKey {
    @MainActor static var defaultValue: AppContainer {
        // PeakApp injects the real container before any feature view renders.
        // Keep the default lightweight — never touch HealthKit, StoreKit, or location here.
        AppContainer(
            healthKit: UnavailableHealthKitService(),
            subscription: InertSubscriptionService()
        )
    }
}

/// Placeholder used only when a view reads `appContainer` without injection (previews / miswired views).
private struct UnavailableHealthKitService: HealthKitServiceProtocol {
    var isAvailable: Bool { false }
    var isAuthorized: Bool { false }
    func requestAuthorization() async throws { throw PeakError.healthKitNotAvailable }
    func fetchDailyMetrics(for date: Date) async -> DailyHealthMetrics { DailyHealthMetrics(date: date) }
    func enableBackgroundDelivery() async throws {}
    func fetchSleepSummary(days: Int) async -> [DailyHealthMetrics] { [] }
    func writeHydration(ml: Int, date: Date) async throws {}
}

@MainActor
private final class InertSubscriptionService: SubscriptionServiceProtocol {
    var currentTier: SubscriptionTier { .free }
    var status: SubscriptionStatus { .none }
    var products: [Product] { [] }
    func loadProducts() async {}
    func purchase(_ product: Product) async throws -> Bool { false }
    func restorePurchases() async throws {}
    func updateSubscriptionStatus() async {}
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
