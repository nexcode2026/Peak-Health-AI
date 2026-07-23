import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ProfileViewModel {
    var profile: UserProfile?
    var showPaywall = false
    var showDeleteConfirmation = false
    var exportURL: URL?
    var alertMessage: String?
    var healthKitAuthorized = false

    func load(modelContext: ModelContext, container: AppContainer) {
        profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first
        healthKitAuthorized = container.healthKit.isAuthorized
    }

    func updateGoals(
        recovery: Int,
        water: Int,
        sleep: Double,
        modelContext: ModelContext
    ) {
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
                let success = try await container.biometrics.authenticate(
                    reason: "Enable \(container.biometrics.biometricType) for Peak"
                )
                if success {
                    profile?.faceIDEnabled = true
                    try? modelContext.save()
                }
            } catch {
                profile?.faceIDEnabled = false
            }
        } else {
            profile?.faceIDEnabled = false
            try? modelContext.save()
        }
    }

    func exportData(format: ExportFormat, modelContext: ModelContext, container: AppContainer) {
        guard let profile else { return }
        do {
            switch format {
            case .csv:
                exportURL = try container.export.exportCSV(modelContext: modelContext)
            case .pdf:
                exportURL = try container.export.exportPDF(modelContext: modelContext, profile: profile)
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func deleteAccount(modelContext: ModelContext, container: AppContainer) throws {
        for model in PeakSchema.allModels {
            try modelContext.delete(model: model)
        }
        try container.auth.signOut(modelContext: modelContext)
        container.keychain.deleteAll()
    }

    enum ExportFormat {
        case csv, pdf
    }
}