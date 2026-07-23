import SwiftData
import SwiftUI

// MARK: - Shared preview fixtures for Xcode Canvas

@MainActor
enum PeakPreview {
    private static var cachedContainer: ModelContainer?

    static var modelContainer: ModelContainer {
        if let cachedContainer { return cachedContainer }
        let container = SampleDataGenerator.previewContainer()
        cachedContainer = container
        return container
    }

    private static var cachedAppContainer: AppContainer?
    static var appContainer: AppContainer {
        if let cachedAppContainer { return cachedAppContainer }
        let container = AppContainer()
        cachedAppContainer = container
        return container
    }

    static var modelContext: ModelContext {
        modelContainer.mainContext
    }

    static var profile: UserProfile? {
        try? modelContext.fetch(FetchDescriptor<UserProfile>()).first
    }

    static var snapshot: DailyHealthSnapshot {
        DailyHealthSnapshot.build(
            metrics: DailyHealthMetrics(
                sleepHours: 7.5,
                sleepQuality: 0.82,
                hrvMS: 68,
                restingHeartRate: 58,
                steps: 8420,
                activeEnergyKcal: 420
            ),
            hydrationML: 1800,
            hydrationGoal: 2500,
            calories: 1450,
            calorieGoal: 2200,
            protein: 95,
            habitsCompleted: 4,
            habitsTotal: 6
        )
    }
}

extension View {
    /// Applies in-memory SwiftData, AppContainer, and profile-driven preferences.
    func peakPreviewShell() -> some View {
        self
            .modelContainer(PeakPreview.modelContainer)
            .environment(\.appContainer, PeakPreview.appContainer)
            .applyProfilePreferences()
    }
}