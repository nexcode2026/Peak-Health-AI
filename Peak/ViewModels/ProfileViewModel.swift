import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ProfileViewModel {
    var profile: UserProfile?
    var achievements: [Achievement] = []
    var unlockedCount: Int = 0
    var healthMetrics: DailyHealthMetrics?
    var showPaywall = false
    var showDeleteConfirmation = false
    var exportURL: URL?
    var alertMessage: String?
    var healthKitAuthorized = false

    func load(modelContext: ModelContext, container: AppContainer) {
        profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first
        healthKitAuthorized = container.healthKit.isAuthorized
        AchievementService.ensureAllAchievementsExist(modelContext: modelContext)
        AchievementService.evaluateAll(modelContext: modelContext)
        achievements = (try? modelContext.fetch(FetchDescriptor<Achievement>(
            sortBy: [SortDescriptor(\.unlockedAt, order: .reverse)]
        ))) ?? []
        unlockedCount = achievements.filter(\.isUnlocked).count
    }

    func updateAvatar(data: Data?, modelContext: ModelContext) {
        profile?.avatarData = data
        profile?.updatedAt = Date()
        try? modelContext.save()
        PeakHaptics.success()
    }

    func updateGoals(recovery: Int, water: Int, sleep: Double, modelContext: ModelContext) {
        profile?.recoveryTarget = recovery
        profile?.dailyWaterGoalML = water
        profile?.sleepHoursTarget = sleep
        profile?.updatedAt = Date()
        try? modelContext.save()
        PeakHaptics.success()
    }

    func toggleFaceID(enabled: Bool, container: AppContainer, modelContext: ModelContext) async {
        if enabled {
            do {
                if try await container.biometrics.authenticate(reason: "Enable \(container.biometrics.biometricType)") {
                    profile?.faceIDEnabled = true
                    try? modelContext.save()
                }
            } catch { profile?.faceIDEnabled = false }
        } else {
            profile?.faceIDEnabled = false
            try? modelContext.save()
        }
    }

    func syncHealthKit(container: AppContainer) async {
        guard container.healthKit.isAvailable else { return }
        healthMetrics = await container.healthKit.fetchDailyMetrics(for: Date().startOfDay)
    }

    func exportData(format: ExportFormat, modelContext: ModelContext, container: AppContainer) {
        guard let profile else { return }
        do {
            switch format {
            case .csv: exportURL = try container.export.exportCSV(modelContext: modelContext)
            case .pdf: exportURL = try container.export.exportPDF(modelContext: modelContext, profile: profile)
            }
        } catch { alertMessage = error.localizedDescription }
    }

    func deleteAccount(modelContext: ModelContext, container: AppContainer) throws {
        for model in PeakSchema.allModels { try modelContext.delete(model: model) }
        try container.auth.signOut(modelContext: modelContext)
        container.keychain.deleteAll()
        OnboardingStorage.markIncomplete()
        try? modelContext.save()
    }

    enum ExportFormat { case csv, pdf }
}