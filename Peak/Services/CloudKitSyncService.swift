import CloudKit
import Foundation
import SwiftData

/// Monitors CloudKit account readiness and surfaces sync status for Profile / Today banners.
@MainActor
@Observable
final class CloudKitSyncService {
    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    private(set) var statusMessage: String = "Checking iCloud…"
    private(set) var lastChecked: Date?
    private(set) var isSyncEnabled: Bool = false

    func refreshStatus() async {
        let (status, error) = await CloudKitDiagnostics.accountStatus()
        accountStatus = status
        lastChecked = .now
        isSyncEnabled = ModelContainerFactory.isCloudKitEnabled

        if let error {
            statusMessage = error
            return
        }

        switch status {
        case .available:
            if isSyncEnabled {
                statusMessage = "iCloud sync is active. Data syncs across your devices."
            } else if OnboardingStorage.cloudKitSyncEnabled {
                statusMessage = "iCloud sync will activate on next launch. Force quit and reopen Peak."
            } else {
                statusMessage = "iCloud available. Enable sync in You → iCloud."
            }
        case .noAccount:
            statusMessage = "Sign into iCloud in Settings → Apple ID to sync across devices."
        case .restricted:
            statusMessage = "iCloud is restricted on this device."
        case .temporarilyUnavailable:
            statusMessage = "iCloud is temporarily unavailable. Try again shortly."
        case .couldNotDetermine:
            statusMessage = "Could not determine iCloud status."
        @unknown default:
            statusMessage = "Unknown iCloud status."
        }
    }

    /// Opt-in flow. SwiftData creates the development schema when the signed app opens its store.
    func enableSyncOnNextLaunch() {
        ModelContainerFactory.enableCloudKitSyncOnNextLaunch()
        statusMessage = ModelContainerFactory.lastCloudKitError
            ?? "iCloud sync enabled. Force quit Peak and reopen."
    }

    func scheduleRecovery() {
        ModelContainerFactory.scheduleCloudKitRecovery()
        statusMessage = ModelContainerFactory.lastCloudKitError
            ?? "CloudKit cache cleared. Reopen Peak to retry."
    }

    var canEnableSync: Bool {
        CloudKitDiagnostics.isAccountReady(accountStatus) && !isSyncEnabled
    }

    var syncIcon: String {
        isSyncEnabled ? "icloud.fill" : "icloud.slash"
    }
}
