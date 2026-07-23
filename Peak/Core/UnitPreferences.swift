import SwiftData
import SwiftUI

// MARK: - Unit system (stored as metric internally; display converts)

enum UnitSystem: String, CaseIterable, Equatable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }

    var detail: String {
        switch self {
        case .metric: "Kilograms, centimeters, kilometers and milliliters"
        case .imperial: "Pounds, feet and inches, miles and fluid ounces"
        }
    }

    init(preferredUnits: String) {
        self = preferredUnits == "imperial" ? .imperial : .metric
    }
}

struct UnitPreferences: Equatable {
    var preferredUnits: String = "metric"

    var system: UnitSystem { UnitSystem(preferredUnits: preferredUnits) }

    var formatter: UnitFormatter { UnitFormatter(system: system) }
}

struct UnitFormatter: Equatable {
    let system: UnitSystem

    // MARK: - Water (stored as ml)

    func formatWater(_ ml: Int) -> String {
        switch system {
        case .metric:
            return "\(ml) ml"
        case .imperial:
            return "\(formattedFluidOunces(ml)) fl oz"
        }
    }

    func formatWaterShort(_ ml: Int) -> String {
        switch system {
        case .metric:
            return "\(ml)"
        case .imperial:
            return formattedFluidOunces(ml)
        }
    }

    var waterUnitLabel: String {
        system == .metric ? "ml" : "fl oz"
    }

    func formatWaterGoal(_ ml: Int) -> String {
        switch system {
        case .metric:
            return "Goal \(ml) ml"
        case .imperial:
            return "Goal \(formattedFluidOunces(ml)) fl oz"
        }
    }

    /// US fluid ounces. Peak stores hydration in milliliters so changing the
    /// presentation unit never alters HealthKit or CloudKit values.
    private func formattedFluidOunces(_ ml: Int) -> String {
        let ounces = Double(ml) / 29.5735
        if abs(ounces.rounded() - ounces) < 0.05 {
            return String(format: "%.0f", ounces)
        }
        return String(format: "%.1f", ounces)
    }

    // MARK: - Weight (stored as kg)

    func formatWeight(_ kg: Double) -> String {
        switch system {
        case .metric:
            return String(format: "%.1f kg", kg)
        case .imperial:
            return String(format: "%.1f lb", kg * 2.20462)
        }
    }

    // MARK: - Height (stored as cm)

    func formatHeight(_ cm: Double) -> String {
        switch system {
        case .metric:
            return "\(Int(cm)) cm"
        case .imperial:
            let totalInches = cm / 2.54
            let feet = Int(totalInches) / 12
            let inches = Int(totalInches) % 12
            return "\(feet)'\(inches)\""
        }
    }

    // MARK: - Distance (stored as km)

    func formatDistance(_ km: Double) -> String {
        switch system {
        case .metric:
            return String(format: "%.1f km", km)
        case .imperial:
            return String(format: "%.1f mi", km * 0.621371)
        }
    }

    var distanceUnitLabel: String {
        system == .metric ? "km" : "mi"
    }

    func parseDistanceInput(_ value: Double) -> Double {
        switch system {
        case .metric: return value
        case .imperial: return value / 0.621371
        }
    }

    func displayDistanceValue(_ km: Double) -> Double {
        switch system {
        case .metric: return km
        case .imperial: return km * 0.621371
        }
    }

    // MARK: - Temperature (stored as Celsius)

    func formatTemperature(_ celsius: Double) -> String {
        switch system {
        case .metric: return "\(Int(celsius.rounded()))°C"
        case .imperial: return "\(Int((celsius * 9 / 5 + 32).rounded()))°F"
        }
    }
}

// MARK: - Environment

private struct UnitPreferencesKey: EnvironmentKey {
    static let defaultValue = UnitPreferences()
}

extension EnvironmentValues {
    var unitPreferences: UnitPreferences {
        get { self[UnitPreferencesKey.self] }
        set { self[UnitPreferencesKey.self] = newValue }
    }
}

// MARK: - App info (version + build from target)

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    static var versionBuildLine: String {
        "Version \(version) (\(build))"
    }
}

// MARK: - Appearance

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    static func colorScheme(for preference: String) -> ColorScheme? {
        switch AppearancePreference(rawValue: preference) ?? .system {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

/// Injects unit preferences and appearance from the active user profile.
struct ProfilePreferencesModifier: ViewModifier {
    @Query private var profiles: [UserProfile]

    func body(content: Content) -> some View {
        let profile = profiles.first
        content
            .environment(\.unitPreferences, UnitPreferences(preferredUnits: profile?.preferredUnits ?? "metric"))
            .preferredColorScheme(AppearancePreference.colorScheme(for: profile?.darkModePreference ?? "system"))
    }
}

extension View {
    func applyProfilePreferences() -> some View {
        modifier(ProfilePreferencesModifier())
    }
}
