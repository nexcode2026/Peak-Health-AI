import Foundation
import OSLog

// MARK: - App Errors

enum PeakError: LocalizedError, Equatable {
    case healthKitNotAvailable
    case healthKitAuthorizationDenied
    case healthKitQueryFailed(String)
    case cloudKitSyncFailed(String)
    case authenticationFailed(String)
    case subscriptionFailed(String)
    case aiServiceUnavailable
    case aiRateLimitExceeded
    case aiAPIKeyMissing
    case exportFailed(String)
    case dataNotFound
    case invalidInput(String)
    case faceIDNotAvailable
    case faceIDFailed
    case networkUnavailable
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "Health data is not available on this device."
        case .healthKitAuthorizationDenied:
            return "Peak needs Health access to calculate your recovery score. Enable it in Settings → Health → Peak."
        case .healthKitQueryFailed(let detail):
            return "Couldn't read health data: \(detail)"
        case .cloudKitSyncFailed(let detail):
            return "iCloud sync issue: \(detail)"
        case .authenticationFailed(let detail):
            return "Sign in failed: \(detail)"
        case .subscriptionFailed(let detail):
            return "Subscription error: \(detail)"
        case .aiServiceUnavailable:
            return "Peak Coach is temporarily unavailable. Try again shortly."
        case .aiRateLimitExceeded:
            return "You've reached your AI message limit. Upgrade to Premium for more."
        case .aiAPIKeyMissing:
            return "Connect your xAI API key in Settings to use advanced coaching."
        case .exportFailed(let detail):
            return "Export failed: \(detail)"
        case .dataNotFound:
            return "No data found."
        case .invalidInput(let detail):
            return detail
        case .faceIDNotAvailable:
            return "Face ID is not available on this device."
        case .faceIDFailed:
            return "Face ID authentication failed."
        case .networkUnavailable:
            return "No internet connection."
        case .unknown(let detail):
            return detail
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .healthKitAuthorizationDenied:
            return "Open Settings to grant Health permissions."
        case .aiRateLimitExceeded:
            return "View subscription options in Profile."
        case .networkUnavailable:
            return "Peak works offline. Cloud sync will resume when connected."
        default:
            return nil
        }
    }
}

// MARK: - Logger

enum PeakLogger {
    private static let subsystem = PeakConstants.bundleIdentifier

    static let general = Logger(subsystem: subsystem, category: "general")
    static let healthKit = Logger(subsystem: subsystem, category: "healthkit")
    static let cloudKit = Logger(subsystem: subsystem, category: "cloudkit")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let subscription = Logger(subsystem: subsystem, category: "subscription")
    static let recovery = Logger(subsystem: subsystem, category: "recovery")
}