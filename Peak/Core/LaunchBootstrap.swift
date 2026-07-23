@preconcurrency import Foundation
import UIKit

/// Startup helpers for avoiding SIGABRT from protected-data / store timing issues.
enum LaunchBootstrap {
    /// `NSFileProtectionComplete` blocks SQLite until the device is unlocked.
    /// Opening SwiftData before unlock can abort the process (not catchable in Swift).
    @MainActor
    static func waitForProtectedData(onWaiting: (@MainActor (String) -> Void)? = nil) async -> Bool {
        guard !UIApplication.shared.isProtectedDataAvailable else {
            PeakLogger.general.info("Protected data already available.")
            return true
        }

        PeakLogger.general.warning("Waiting for protected data before opening SwiftData store...")
        onWaiting?("Unlock your iPhone to open Peak…")

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            var finished = false
            func finish(_ available: Bool, _ reason: String) {
                guard !finished else { return }
                finished = true
                PeakLogger.general.info("\(reason)")
                continuation.resume(returning: available)
            }

            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: UIApplication.protectedDataDidBecomeAvailableNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let token {
                    NotificationCenter.default.removeObserver(token)
                }
                token = nil
                finish(true, "Protected data became available.")
            }

            // Do not open the store on timeout — that triggers SIGABRT with Complete protection.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(60))
                finish(false, "Protected data still unavailable after 60s.")
            }
        }
    }

    @MainActor
    static var isProtectedDataAvailable: Bool {
        UIApplication.shared.isProtectedDataAvailable
    }

    static func logPhase(_ phase: String) {
        PeakLogger.general.info("Launch phase: \(phase)")
    }
}

