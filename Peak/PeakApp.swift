import SwiftData
import SwiftUI
import UIKit

@main
struct PeakApp: App {
    @State private var bootstrap: ModelContainerBootstrap?
    @State private var container: AppContainer?
    @State private var bootstrapFailed = false

    @State private var needsSignIn = false
    @State private var showOnboarding = false
    @State private var isLocked = false
    @State private var selectedTab: PeakTab = .today
    @State private var isLaunching = true
    @State private var launchMessage = "Loading Peak..."

    init() {
        OnboardingStorage.markLaunchStarted()
        LaunchBootstrap.logPhase("PeakApp.init")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if bootstrapFailed {
                    DataStoreFailureView()
                } else if let bootstrap, let container, !isLaunching {
                    RootView(
                        needsSignIn: $needsSignIn,
                        showOnboarding: $showOnboarding,
                        isLocked: $isLocked,
                        selectedTab: $selectedTab
                    )
                    .id(ObjectIdentifier(bootstrap.container))
                    .environment(\.appContainer, container)
                    .modelContainer(bootstrap.container)
                    .applyProfilePreferences()
                    .overlay {
                        if let unlock = container.pendingAchievementUnlock {
                            AchievementCelebrationView(achievement: unlock) {
                                container.pendingAchievementUnlock = nil
                            }
                        }
                    }
                } else {
                    LaunchScreenView(message: launchMessage)
                        .task {
                            await bootstrapIfNeeded()
                        }
                }
            }
            .tint(PeakTheme.accent)
        }
    }

    @MainActor
    private func bootstrapIfNeeded() async {
        guard bootstrap == nil, !bootstrapFailed else { return }

        LaunchBootstrap.logPhase("bootstrapIfNeeded.start")
        launchMessage = "Preparing your data..."

        let protectedDataReady = await LaunchBootstrap.waitForProtectedData { message in
            launchMessage = message
        }

        launchMessage = protectedDataReady ? "Opening database..." : "Waiting for device unlock..."

        let loaded = await Task.detached(priority: .userInitiated) {
            ModelContainerFactory.makeBootstrap(allowPersistentStore: protectedDataReady)
        }.value

        guard let loaded else {
            bootstrapFailed = true
            isLaunching = false
            OnboardingStorage.markLaunchFinished()
            return
        }

        bootstrap = loaded
        let services = AppContainer()
        container = services

        launchMessage = loaded.mode == .cloudKitPrivate || loaded.mode == .cloudKitAutomatic
            ? "Syncing with iCloud..."
            : "Preparing your data..."

        let context = loaded.container.mainContext
        await services.configure(modelContext: context)
        await applyAuthAndOnboardingState(context: context, services: services)

#if DEBUG
        let launchDelay: Duration = ProcessInfo.processInfo.arguments.contains("-PeakSlowLaunch")
            ? .seconds(12)
            : .milliseconds(600)
        try? await Task.sleep(for: launchDelay)
#else
        try? await Task.sleep(for: .milliseconds(600))
#endif

        withAnimation(.easeOut(duration: 0.35)) {
            isLaunching = false
        }

        LaunchBootstrap.logPhase("bootstrapIfNeeded.complete mode=\(loaded.mode.rawValue)")
        OnboardingStorage.markLaunchFinished()

        // Health authorization belongs to onboarding / explicit Connect actions.
        // Starting it here can block a fresh launch behind a system permission sheet.
        let isDemoMode = ProcessInfo.processInfo.arguments.contains("-PeakDemoMode")
        if !isDemoMode, !needsSignIn, !showOnboarding, HealthKitAuthStorage.hasRequested {
            await services.startHealthLiveSync()
        }
    }

    @MainActor
    private func applyAuthAndOnboardingState(context: ModelContext, services: AppContainer) async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PeakDemoMode") {
            prepareDemoProfile(context: context)
            needsSignIn = false
            showOnboarding = false
            isLocked = false
            if ProcessInfo.processInfo.arguments.contains("-PeakShowIconPicker") ||
                ProcessInfo.processInfo.arguments.contains("-PeakShowPaywall") {
                selectedTab = .you
            }
            return
        }
#endif

        recoverProfileIfNeeded(context: context, services: services)

        let credentialValid = await services.auth.checkCredentialState()
        if !services.auth.isSignedIn || !credentialValid {
            needsSignIn = true
            showOnboarding = false
            isLocked = false
            return
        }

        needsSignIn = false

        if let profile = activeProfile(context: context, userID: services.auth.currentUserID),
           profile.onboardingCompleted {
            OnboardingStorage.hasCompletedOnboarding = true
            showOnboarding = false
            isLocked = profile.faceIDEnabled
        } else {
            showOnboarding = true
            isLocked = false
        }
    }

#if DEBUG
    @MainActor
    private func prepareDemoProfile(context: ModelContext) {
        let demoID = "peak-debug-demo"
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.appleUserID == demoID })
        let profile: UserProfile
        if let existing = try? context.fetch(descriptor).first {
            profile = existing
        } else {
            profile = UserProfile(appleUserID: demoID, displayName: "Alex Morgan", email: "demo@peak.local")
            context.insert(profile)
        }
        profile.onboardingCompleted = true
        profile.preferredUnits = ProcessInfo.processInfo.arguments.contains("-PeakDemoImperial") ? "imperial" : "metric"
        profile.darkModePreference = "system"
        if ProcessInfo.processInfo.arguments.contains("-PeakDemoFemale") {
            profile.gender = GenderOption.female.rawValue
            profile.cycleTrackingEnabled = true
        }
        if ProcessInfo.processInfo.arguments.contains("-PeakDemoHealthFirst") {
            profile.todaySectionOrder = ([.health] + TodaySection.defaultOrder.filter { $0 != .health })
                .map(\.rawValue)
                .joined(separator: ",")
            profile.todayHiddenSections = ""
            profile.healthMetricLayout = TodayMetricLayout.compact.rawValue
            profile.todayHiddenHealthMetrics = ""
        }
        if !profile.sampleDataLoaded {
            SampleDataGenerator.populate(context: context, profile: profile)
            profile.sampleDataLoaded = true
        }
        try? context.save()
    }
#endif

    @MainActor
    private func recoverProfileIfNeeded(context: ModelContext, services: AppContainer) {
        let existing = activeProfile(context: context, userID: services.auth.currentUserID)
        guard existing == nil,
              let userID = services.auth.currentUserID else { return }

        let profile = UserProfile(appleUserID: userID, displayName: "Peak User")
        profile.onboardingCompleted = false
        context.insert(profile)
        try? context.save()
        PeakLogger.general.info("Recovered user profile from keychain for \(userID)")
    }

    @MainActor
    private func activeProfile(context: ModelContext, userID: String?) -> UserProfile? {
        guard let userID else { return nil }
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.appleUserID == userID })
        return try? context.fetch(descriptor).first
    }
}

private struct DataStoreFailureView: View {
    var body: some View {
        VStack(spacing: PeakTheme.Spacing.lg) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(PeakTheme.error)

            Text("Peak Couldn't Start")
                .font(PeakTheme.Typography.largeTitle)

            Text(ModelContainerFactory.lastCloudKitError
                ?? "Delete Peak from your device, then build and run again from Xcode.")
                .font(PeakTheme.Typography.body)
                .foregroundStyle(PeakTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PeakTheme.background)
    }
}

struct RootView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Binding var needsSignIn: Bool
    @Binding var showOnboarding: Bool
    @Binding var isLocked: Bool
    @Binding var selectedTab: PeakTab

    var body: some View {
        Group {
            if needsSignIn {
                SignInView {
                    Task { await refreshAuthState() }
                }
            } else if showOnboarding {
                OnboardingView {
                    showOnboarding = false
                    needsSignIn = false
                }
            } else if isLocked {
                LockScreenView {
                    isLocked = false
                }
            } else {
                MainTabView(selectedTab: $selectedTab) {
                    needsSignIn = true
                    showOnboarding = false
                    isLocked = false
                }
            }
        }
    }

    @MainActor
    private func refreshAuthState() async {
        let signedIn = await container.auth.checkCredentialState()
        guard signedIn, container.auth.isSignedIn else {
            needsSignIn = true
            return
        }
        needsSignIn = false
        let userID = container.auth.currentUserID ?? ""
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.appleUserID == userID })
        if let profile = try? modelContext.fetch(descriptor).first,
           profile.onboardingCompleted {
            showOnboarding = false
            isLocked = profile.faceIDEnabled
        } else {
            showOnboarding = true
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: PeakTab
    var onSessionEnded: () -> Void = {}
    @State private var isQuickLogOpen = false
    @State private var requestedQuickAction: DashboardViewModel.QuickAction?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                switch selectedTab {
                case .today:
                    DashboardView(requestedQuickAction: $requestedQuickAction) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            selectedTab = .you
                        }
                    }
                case .journal:
                    TrackView()
                case .trends:
                    InsightsView()
                case .coach:
                    CoachView()
                case .you:
                    ProfileView(onSessionEnded: onSessionEnded)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(alignment: .bottom, spacing: PeakTheme.Spacing.sm) {
                BevelTabBar(selectedTab: $selectedTab)
                Spacer(minLength: 0)
                if selectedTab == .today {
                    quickLogControl
                        .transition(.scale(scale: 0.9, anchor: .bottomTrailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.bottom, 1)
            .zIndex(10)

            if selectedTab == .today && isQuickLogOpen {
                quickLogMenu
                    .padding(.trailing, 10)
                    .padding(.bottom, 55)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(11)
            }
        }
        .background(PeakTheme.background.ignoresSafeArea())
        .onChange(of: selectedTab) { _, _ in
            if isQuickLogOpen {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    isQuickLogOpen = false
                }
            }
        }
    }

    private var quickLogControl: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                isQuickLogOpen.toggle()
            }
            PeakHaptics.selection()
        } label: {
            Image(systemName: isQuickLogOpen ? "xmark" : "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isQuickLogOpen ? PeakTheme.textPrimary : .white)
                .contentTransition(.symbolEffect(.replace))
                .rotationEffect(.degrees(isQuickLogOpen ? 90 : 0))
                .frame(width: 46, height: 46)
                .background(PeakTheme.accent.opacity(isQuickLogOpen ? 0.12 : 0.94), in: Circle())
                .overlay { Circle().stroke(Color.white.opacity(0.28), lineWidth: 0.7) }
                .shadow(color: PeakTheme.accent.opacity(0.30), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isQuickLogOpen ? "Close quick log menu" : "Open quick log menu")
        .accessibilityHint("Log water, a meal, a workout, or your mood")
    }

    private var quickLogMenu: some View {
        VStack(spacing: 2) {
            quickLogButton(.water, title: "Water", icon: "drop.fill", color: PeakTheme.teal)
            quickLogButton(.meal, title: "AI Meal", icon: "sparkles.rectangle.stack.fill", color: PeakTheme.coral)
            quickLogButton(.workout, title: "Workout", icon: "figure.run", color: PeakTheme.lavender)
            quickLogButton(.mood, title: "Mood", icon: "face.smiling.fill", color: PeakTheme.gold)
        }
        .padding(6)
        .frame(width: 156)
        .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: PeakTheme.accent.opacity(0.06))
    }

    private func quickLogButton(
        _ action: DashboardViewModel.QuickAction,
        title: String,
        icon: String,
        color: Color
    ) -> some View {
        Button {
            requestedQuickAction = action
            withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                isQuickLogOpen = false
            }
            PeakHaptics.selection()
        } label: {
            HStack(spacing: PeakTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.13), in: Circle())
                Text(title)
                    .font(PeakTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(PeakTheme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(height: 40)
            .contentShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick log \(title)")
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
                .foregroundStyle(PeakTheme.accent)

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
