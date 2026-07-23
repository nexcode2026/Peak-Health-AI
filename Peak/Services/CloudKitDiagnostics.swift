import CloudKit
import Foundation

enum CloudKitDiagnostics {
    static func accountStatus() async -> (CKAccountStatus, String?) {
        let container = CKContainer(identifier: PeakConstants.cloudKitContainer)
        do {
            let status = try await container.accountStatus()
            return (status, nil)
        } catch {
            return (.couldNotDetermine, error.localizedDescription)
        }
    }

    static func accountStatusLabel(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: return "iCloud account available"
        case .noAccount: return "No iCloud account on this device"
        case .restricted: return "iCloud is restricted on this device"
        case .temporarilyUnavailable: return "iCloud temporarily unavailable"
        case .couldNotDetermine: return "Could not determine iCloud status"
        @unknown default: return "Unknown iCloud status"
        }
    }

    static func isAccountReady(_ status: CKAccountStatus) -> Bool {
        status == .available
    }
}