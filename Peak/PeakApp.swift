import SwiftData
import SwiftUI

@main
struct PeakApp: App {
    @State private var container = AppContainer()
    @State private var showOnboarding = true
    @State private var isLocked = false
    @State private var selectedTab = 0

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(PeakSchema.allModels)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(PeakConstants.cloudKitContainer)
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Fallback without CloudKit for simulator/dev without iCloud
            PeakLogger.cloudKit.warning("CloudKit container failed, using local-only: \(error.localizedDescription)")
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: localConfig)
            } catch {
                PeakLogger.cloudKit.error("Local container failed, using in-memory: \(error.localizedDescription)")
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: memoryConfig)
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView(
                showOnboarding: $showOnboarding,
                isLocked: $isLocked,
                selectedTab: $selectedTab
            )
            .environment(\.appContainer, container)
            .modelContainer(sharedModelContainer)
            .preferredColorScheme(nil)
            .task {
                let context = sharedModelContainer.mainContext
                await container.configure(modelContext: context)
                checkOnboardingState(context: context)
            }
        }
    }

    private func checkOnboardingState(context: ModelContext) {
        if let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first,
           profile.onboardingCompleted {
            showOnboarding = false
            if profile.faceIDEnabled {
                isLocked = true
            }
        }
    }
}

struct RootView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Binding var showOnboarding: Bool
    @Binding var isLocked: Bool
    @Binding var selectedTab: Int

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView {
                    showOnboarding = false
                }
            } else if isLocked {
                LockScreenView {
                    isLocked = false
                }
            } else {
                MainTabView(selectedTab: $selectedTab)
            }
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            TrackView()
                .tabItem { Label("Track", systemImage: "plus.circle.fill") }
                .tag(1)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                .tag(2)

            CoachView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(PeakTheme.coral)
    }
}

struct LockScreenView: View {
    @Environment(\.appContainer) private var container
    let onUnlock: () -> Void
    @State private var error: String?

    var body: some View {
        VStack(spacing: PeakTheme.Spacing.xl) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(PeakTheme.teal)

            Text("Peak is Locked")
                .font(PeakTheme.Typography.largeTitle)

            Button("Unlock with \(container.biometrics.biometricType)") {
                Task {
                    do {
                        let success = try await container.biometrics.authenticate(reason: "Unlock Peak")
                        if success { onUnlock() }
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            .buttonStyle(PeakPrimaryButtonStyle())

            if let error {
                Text(error)
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PeakTheme.background)
    }
}