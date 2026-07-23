import Foundation

/// Catalog of bundled Rive animations. Drop matching `.riv` files into `Peak/Resources/Rive/`.
/// Peak animation identifiers — named distinctly from RiveRuntime's `RiveAnimation` type.
enum PeakRiveAnimation: String, CaseIterable, Sendable {
    case recoveryGauge = "recovery_gauge"
    case progressRing = "progress_ring"
    case habitCheck = "habit_check"
    case achievementUnlock = "achievement_unlock"
    case sleepStages = "sleep_stages"
    case hydrationSplash = "hydration_splash"
    case streakFlame = "streak_flame"
    case launchLogo = "launch_logo"

    var fileName: String { rawValue }

    /// Optional state machine input for progress-driven animations (0…100).
    var progressInputName: String? {
        switch self {
        case .recoveryGauge, .progressRing: return "progress"
        case .sleepStages: return "sleepScore"
        default: return nil
        }
    }

    var fallbackSymbol: String {
        switch self {
        case .recoveryGauge: return "bolt.heart.fill"
        case .progressRing: return "circle.circle"
        case .habitCheck: return "checkmark.circle.fill"
        case .achievementUnlock: return "star.fill"
        case .sleepStages: return "moon.zzz.fill"
        case .hydrationSplash: return "drop.fill"
        case .streakFlame: return "flame.fill"
        case .launchLogo: return "mountain.2.fill"
        }
    }
}

enum PeakRiveAnimationLoader {
    static func bundleURL(for animation: PeakRiveAnimation) -> URL? {
        Bundle.main.url(forResource: animation.fileName, withExtension: "riv", subdirectory: "Rive")
            ?? Bundle.main.url(forResource: animation.fileName, withExtension: "riv")
    }

    static func canLoad(_ animation: PeakRiveAnimation) -> Bool {
        bundleURL(for: animation) != nil
    }
}