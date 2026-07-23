import PhotosUI
import SwiftData
import SwiftUI

@MainActor
struct ProfileView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProfileViewModel()
    var onSessionEnded: () -> Void = {}
    @State private var showPaywall = false
    @State private var showGoalsSheet = false
    @State private var showPersonalDetails = false
    @State private var showAchievements = false
    @State private var openAIAPIKey = ""
    @State private var hasOpenAIAPIKey = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showSignOutConfirmation = false
    @State private var showAppIconPicker = false
    @State private var showHealthMonitoring = false
    @State private var showCycleTracking = false

    private var profileFormatter: UnitFormatter {
        UnitFormatter(system: UnitSystem(preferredUnits: viewModel.profile?.preferredUnits ?? "metric"))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    profileHero
                    achievementsStrip
                    accountSection
                    goalsSection
                    healthSection
                    settingsSection
                    aiSection
                    dataSection
                    aboutSection
                }
                .padding(.horizontal, PeakTheme.Spacing.md)
                .peakContentInsets()
            }
            .peakDismissKeyboardOnSwipe()
            .peakScreenBackground()
            .navigationTitle("You")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showGoalsSheet) {
                ExpandedGoalsSheet(profile: viewModel.profile, modelContext: modelContext)
                    .onDisappear { viewModel.load(modelContext: modelContext, container: container) }
            }
            .sheet(isPresented: $showPersonalDetails) {
                PersonalDetailsSheet(profile: viewModel.profile, modelContext: modelContext)
                    .onDisappear { viewModel.load(modelContext: modelContext, container: container) }
            }
            .sheet(isPresented: $showAchievements) { AchievementsGalleryView(achievements: viewModel.achievements) }
            .sheet(isPresented: $showAppIconPicker) { AppIconPickerSheet() }
            .sheet(isPresented: $showHealthMonitoring) {
                NavigationStack {
                    HealthMonitoringView(snapshot: profileHealthSnapshot, profile: viewModel.profile, date: .now)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showHealthMonitoring = false } } }
                }
            }
            .sheet(isPresented: $showCycleTracking) {
                if let profile = viewModel.profile {
                    NavigationStack {
                        CycleTrackingView(profile: profile)
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showCycleTracking = false } } }
                    }
                }
            }
            .sheet(isPresented: .init(get: { viewModel.exportURL != nil }, set: { if !$0 { viewModel.exportURL = nil } })) {
                if let url = viewModel.exportURL { ShareSheet(items: [url]) }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        viewModel.updateAvatar(data: data, modelContext: modelContext)
                    }
                }
            }
            .alert("Delete Account?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Delete", role: .destructive) { endSession(deleteData: true) }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This permanently deletes all your Peak data.") }
            .alert("Sign Out?", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) { endSession(deleteData: false) }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Your data stays in iCloud. Sign in again to sync.") }
        }
        .task {
            viewModel.load(modelContext: modelContext, container: container)
            hasOpenAIAPIKey = container.keychain.read(for: .openAIAPIKey) != nil
            await viewModel.syncHealthKit(container: container)
            await container.cloudKitSync.refreshStatus()
        }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-PeakShowIconPicker") {
                showAppIconPicker = true
            } else if ProcessInfo.processInfo.arguments.contains("-PeakShowPaywall") {
                showPaywall = true
            }
#endif
        }
    }

    // MARK: - Hero

    private var profileHero: some View {
        let avatarName = viewModel.profile?.displayName ?? "P"
        let avatarData = viewModel.profile?.avatarData

        return PeakCard {
            HStack(spacing: PeakTheme.Spacing.lg) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    AvatarView(name: avatarName, avatarData: avatarData, size: 80, showEditBadge: true)
                }

                VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                    Text(viewModel.profile?.displayName ?? "Peak User")
                        .font(PeakTheme.Typography.title)
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill").font(.caption).foregroundStyle(PeakTheme.gold)
                        Text(container.currentTier.displayName)
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.coral)
                    }
                    if let bio = viewModel.profile?.bio, !bio.isEmpty {
                        Text(bio).font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary).lineLimit(2)
                    }
                    if let age = viewModel.profile?.age {
                        Text("\(age) years old · \(viewModel.profile?.activity.displayName ?? "") activity")
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                    if let p = viewModel.profile, p.heightCm > 0, p.weightKg > 0 {
                        Text("\(profileFormatter.formatHeight(p.heightCm)) · \(profileFormatter.formatWeight(p.weightKg))")
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Achievements

    private var achievementsStrip: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: "Achievement Badges", actionTitle: "See All") { showAchievements = true }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PeakTheme.Spacing.md) {
                    ForEach(viewModel.achievements.prefix(6), id: \.id) { a in
                        AchievementBadgeView(achievement: a, size: .small)
                    }
                }
            }
            Text("\(viewModel.unlockedCount) of \(viewModel.achievements.count) unlocked")
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        settingsCard(title: "Account", icon: "person.crop.circle.fill", color: PeakTheme.teal) {
            settingsRow(icon: "person.fill", title: "Personal Details", color: PeakTheme.teal) { showPersonalDetails = true }
            if container.currentTier == .free {
                settingsRow(icon: "crown.fill", title: "Upgrade to Premium", color: PeakTheme.gold) { showPaywall = true }
            }
            settingsRow(icon: "creditcard.fill", title: "Manage Subscription", color: PeakTheme.coral) { showPaywall = true }
            Button { showSignOutConfirmation = true } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(PeakTheme.Typography.body)
                    .foregroundStyle(PeakTheme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var goalsSection: some View {
        let recovery = viewModel.profile?.recoveryTarget ?? 75
        return settingsCard(title: "Goals & Targets", icon: "target", color: PeakTheme.mint) {
            HStack(spacing: PeakTheme.Spacing.md) {
                MetricGauge(
                    progress: Double(recovery) / 100,
                    value: "\(recovery)",
                    label: "Recovery",
                    color: PeakTheme.recoveryColor(for: recovery),
                    size: 88
                )
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                    Text("Your daily blueprint")
                        .font(PeakTheme.Typography.headline)
                    Text("Nine connected goals guide Today, insights and Peak Coach.")
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                    Button { showGoalsSheet = true } label: {
                        Label("Tune Goals", systemImage: "slider.horizontal.3")
                    }
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.accent)
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PeakTheme.Spacing.sm) {
                goalTile("Sleep", value: "\((viewModel.profile?.sleepHoursTarget ?? 8).formattedOneDecimal)h", icon: "moon.zzz.fill", color: PeakTheme.lavender)
                goalTile("Water", value: profileFormatter.formatWater(viewModel.profile?.dailyWaterGoalML ?? 2500), icon: "drop.fill", color: PeakTheme.accent)
                goalTile("Calories", value: "\(viewModel.profile?.dailyCalorieGoal ?? 2200) kcal", icon: "flame.fill", color: PeakTheme.gold)
                goalTile("Protein", value: "\(viewModel.profile?.dailyProteinGoalG ?? 120) g", icon: "bolt.fill", color: PeakTheme.coral)
                goalTile("Steps", value: (viewModel.profile?.dailyStepsGoal ?? 10_000).formatted(), icon: "shoeprints.fill", color: PeakTheme.mint)
                goalTile("Workouts", value: "\(viewModel.profile?.weeklyWorkoutGoal ?? 4)/week", icon: "dumbbell.fill", color: PeakTheme.sky)
            }
        }
    }

    private var healthSection: some View {
        settingsCard(title: "Health Data", icon: "heart.text.square.fill", color: PeakTheme.coral) {
            HStack {
                Label(viewModel.healthKitAuthorized ? "HealthKit Connected" : "HealthKit Not Connected", systemImage: "heart.fill")
                    .foregroundStyle(viewModel.healthKitAuthorized ? PeakTheme.mint : PeakTheme.textSecondary)
                Spacer()
                if !viewModel.healthKitAuthorized {
                    Button("Connect") {
                        Task {
                            _ = try? await container.healthKit.requestAuthorization()
                            await container.startHealthLiveSync()
                            viewModel.load(modelContext: modelContext, container: container)
                        }
                    }
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.coral)
                }
            }
            if let m = viewModel.healthMetrics, m.sleepHours > 0 || m.steps > 0 {
                HStack(spacing: PeakTheme.Spacing.sm) {
                    if m.sleepHours > 0 { miniHealth("moon.fill", "\(m.sleepHours.formattedOneDecimal)h sleep") }
                    if m.hrvMS > 0 { miniHealth("waveform.path.ecg", "\(Int(m.hrvMS)) HRV") }
                    if m.steps > 0 { miniHealth("figure.walk", "\(m.steps) steps") }
                }
            }
            settingsRow(icon: "waveform.path.ecg.magnifyingglass", title: "Health Monitoring", color: PeakTheme.coral) {
                showHealthMonitoring = true
            }
            settingToggle(icon: "arrow.triangle.2.circlepath", title: "Auto-sync HealthKit", detail: "Refresh recovery and activity in the background", color: PeakTheme.mint, isOn: binding(\.autoSyncHealthKit))
            if viewModel.profile?.genderOption == .female {
                settingToggle(
                    icon: "calendar.circle.fill",
                    title: "Cycle Tracking",
                    detail: "Private period, symptom, energy, and cycle notes",
                    color: PeakTheme.rose,
                    isOn: binding(\.cycleTrackingEnabled)
                )
                if viewModel.profile?.cycleTrackingEnabled == true {
                    settingsRow(icon: "leaf.fill", title: "Open Cycle Tracking", color: PeakTheme.rose) {
                        showCycleTracking = true
                    }
                }
            }
        }
    }

    private var profileHealthSnapshot: DailyHealthSnapshot {
        DailyHealthSnapshot.build(
            metrics: viewModel.healthMetrics,
            hydrationML: 0,
            hydrationGoal: viewModel.profile?.dailyWaterGoalML ?? 2500,
            calories: 0,
            calorieGoal: viewModel.profile?.dailyCalorieGoal ?? 2200,
            habitsCompleted: 0,
            habitsTotal: 0
        )
    }

    private func miniHealth(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(PeakTheme.Typography.micro)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(PeakTheme.teal.opacity(0.1))
        .clipShape(Capsule())
        .foregroundStyle(PeakTheme.teal)
    }

    private var settingsSection: some View {
        settingsCard(title: "App Settings", icon: "gearshape.2.fill", color: PeakTheme.ultraviolet) {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                HStack {
                    settingIcon(container.cloudKitSync.syncIcon, color: container.cloudKitSync.isSyncEnabled ? PeakTheme.mint : PeakTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(container.cloudKitSync.isSyncEnabled ? "iCloud Sync Active" : "iCloud Sync Off")
                            .font(PeakTheme.Typography.subheadline)
                        Text("Private cross-device health history")
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                    Spacer()
                    Text(ModelContainerFactory.activeMode.rawValue)
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
                Text(container.cloudKitSync.statusMessage)
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
                if container.cloudKitSync.canEnableSync {
                    Button("Enable iCloud Sync & Restart") {
                        container.cloudKitSync.enableSyncOnNextLaunch()
                    }
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.accent)
                    Button("Reset iCloud Cache & Restart") {
                        container.cloudKitSync.scheduleRecovery()
                    }
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)
                }
            }
            settingToggle(icon: "bell.badge.fill", title: "Notifications", detail: "Reminders, streaks and recovery updates", color: PeakTheme.gold, isOn: binding(\.notificationsEnabled))
            settingToggle(icon: "waveform", title: "Haptic Feedback", detail: "Tactile responses for logs and controls", color: PeakTheme.coral, isOn: binding(\.hapticsEnabled))
            settingToggle(icon: "chart.xyaxis.line", title: "Show Health Metrics", detail: "Display detailed sensor and trend data", color: PeakTheme.sky, isOn: binding(\.showHealthMetrics))
            settingToggle(icon: "faceid", title: "\(container.biometrics.biometricType) Unlock", detail: "Protect Peak when the app opens", color: PeakTheme.mint, isOn: Binding(
                get: { viewModel.profile?.faceIDEnabled ?? false },
                set: { v in Task { await viewModel.toggleFaceID(enabled: v, container: container, modelContext: modelContext) } }
            )).disabled(!container.biometrics.isAvailable)
            preferencePicker(
                title: "Measurements",
                icon: "ruler.fill",
                detail: "Metric or imperial across every screen",
                color: PeakTheme.teal,
                selection: measurementSystemBinding,
                options: UnitSystem.allCases,
                label: { $0.displayName }
            )
            preferencePicker(
                title: "Appearance",
                icon: "paintbrush.fill",
                detail: "System, light or dark glass",
                color: PeakTheme.lavender,
                selection: appearanceBinding,
                options: AppearancePreference.allCases,
                label: { $0.displayName }
            )
            settingToggle(icon: "fork.knife.circle.fill", title: "Meal Reminders", detail: "Gentle prompts to log fuel", color: PeakTheme.gold, isOn: binding(\.mealReminderEnabled))
            settingToggle(icon: "figure.run.circle.fill", title: "Workout Reminders", detail: "Stay aligned with your weekly target", color: PeakTheme.coral, isOn: binding(\.workoutReminderEnabled))
            settingsRow(icon: "app.badge.fill", title: "App Icon", color: PeakTheme.ultraviolet) {
                showAppIconPicker = true
            }
        }
    }

    private var measurementSystemBinding: Binding<UnitSystem> {
        Binding(
            get: { UnitSystem(preferredUnits: viewModel.profile?.preferredUnits ?? "metric") },
            set: { system in
                viewModel.profile?.preferredUnits = system.rawValue
                try? modelContext.save()
                PeakHaptics.selection()
            }
        )
    }

    private var appearanceBinding: Binding<AppearancePreference> {
        Binding(
            get: { AppearancePreference(rawValue: viewModel.profile?.darkModePreference ?? "system") ?? .system },
            set: { appearance in
                viewModel.profile?.darkModePreference = appearance.rawValue
                try? modelContext.save()
                PeakHaptics.selection()
            }
        )
    }

    private func preferencePicker<Option: Hashable>(
        title: String,
        icon: String,
        detail: String,
        color: Color,
        selection: Binding<Option>,
        options: [Option],
        label: @escaping (Option) -> String
    ) -> some View {
        HStack(spacing: PeakTheme.Spacing.sm) {
            settingIcon(icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PeakTheme.Typography.subheadline)
                Text(detail).font(PeakTheme.Typography.micro).foregroundStyle(PeakTheme.textSecondary)
            }
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .labelsHidden()
        }
    }

    private var aiSection: some View {
        settingsCard(title: "Peak Coach · OpenAI", icon: "sparkles", color: PeakTheme.ultraviolet) {
            HStack(spacing: PeakTheme.Spacing.sm) {
                ZStack {
                    Circle().fill(PeakTheme.ultraviolet.opacity(0.13))
                    Image(systemName: "sparkles").foregroundStyle(PeakTheme.ultraviolet)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("GPT-5.6 Terra")
                        .font(PeakTheme.Typography.subheadline)
                    Text(hasOpenAIAPIKey ? "Private key saved in Keychain" : "On-device Coach is active")
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(hasOpenAIAPIKey ? PeakTheme.mint : PeakTheme.textSecondary)
                }
                Spacer()
                Image(systemName: hasOpenAIAPIKey ? "checkmark.shield.fill" : "iphone.gen3")
                    .foregroundStyle(hasOpenAIAPIKey ? PeakTheme.mint : PeakTheme.accent)
            }

            Toggle("Use OpenAI for coaching and meal analysis", isOn: Binding(
                get: { viewModel.profile?.useOpenAIAPI ?? false },
                set: { enabled in
                    viewModel.profile?.useOpenAIAPI = enabled
                    try? modelContext.save()
                }
            ))
            .tint(PeakTheme.accent)

            HStack {
                SecureField("OpenAI API key", text: $openAIAPIKey)
                    .textContentType(.password)
                    .onSubmit { saveAPIKey() }
                Button("Save") { saveAPIKey() }
                    .disabled(openAIAPIKey.trimmed.isEmpty)
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.accent)
            }
            if hasOpenAIAPIKey {
                Button(role: .destructive) {
                    container.keychain.delete(for: .openAIAPIKey)
                    hasOpenAIAPIKey = false
                    viewModel.profile?.useOpenAIAPI = false
                    try? modelContext.save()
                } label: {
                    Label("Remove OpenAI Key", systemImage: "trash")
                }
                .font(PeakTheme.Typography.caption)
            }
            Text("When enabled, Peak sends the Coach your compact recovery, sleep, hydration, habit, mood, status, goal, and optional cycle summary. The key never syncs to iCloud. On-device fallback remains available.")
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dataSection: some View {
        settingsCard(title: "Privacy & Data", icon: "hand.raised.fill", color: PeakTheme.teal) {
            settingsRow(icon: "square.and.arrow.up", title: "Export CSV", color: PeakTheme.teal) {
                viewModel.exportData(format: .csv, modelContext: modelContext, container: container)
            }
            if container.currentTier != .free {
                settingsRow(icon: "doc.richtext", title: "Export PDF Report", color: PeakTheme.lavender) {
                    viewModel.exportData(format: .pdf, modelContext: modelContext, container: container)
                }
            }
            Button("Delete Account", role: .destructive) { viewModel.showDeleteConfirmation = true }
                .font(PeakTheme.Typography.body)
        }
    }

    private var aboutSection: some View {
        settingsCard(title: "About", icon: "info.circle.fill", color: PeakTheme.sky) {
            Link("Privacy Policy", destination: URL(string: PeakConstants.URLs.privacyPolicy)!)
            Link("Terms of Service", destination: URL(string: PeakConstants.URLs.termsOfService)!)
            Link("Support", destination: URL(string: PeakConstants.URLs.support)!)
            LabeledContent("Version", value: AppInfo.version)
            LabeledContent("Build", value: AppInfo.build)
            DisclaimerBanner(compact: true)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsCard(title: String, icon: String, color: Color, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            HStack(spacing: PeakTheme.Spacing.sm) {
                ZStack {
                    Circle().fill(color.opacity(0.14))
                    Image(systemName: icon).font(.caption).foregroundStyle(color)
                }
                .frame(width: 30, height: 30)
                Text(title).font(PeakTheme.Typography.headline)
            }
            PeakCard {
                VStack(spacing: PeakTheme.Spacing.sm) { content() }
            }
        }
    }

    private func settingsRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: PeakTheme.Spacing.sm) {
                settingIcon(icon, color: color)
                Text(title).foregroundStyle(PeakTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(PeakTheme.textSecondary)
            }
        }
    }

    private func settingIcon(_ icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.opacity(0.13))
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
        }
        .frame(width: 34, height: 34)
    }

    private func settingToggle(
        icon: String,
        title: String,
        detail: String,
        color: Color,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: PeakTheme.Spacing.sm) {
                settingIcon(icon, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(PeakTheme.Typography.subheadline)
                    Text(detail)
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
        }
        .tint(color)
    }

    private func goalTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: PeakTheme.Spacing.xs) {
            settingIcon(icon, color: color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
                Text(value)
                    .font(PeakTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(PeakTheme.textPrimary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(PeakTheme.Spacing.xs)
        .glassCard(cornerRadius: PeakTheme.Radius.sm, tint: color.opacity(0.04))
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<UserProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.profile?[keyPath: keyPath] ?? false },
            set: { v in
                viewModel.profile?[keyPath: keyPath] = v
                try? modelContext.save()
                if let p = viewModel.profile { container.notifications.configure(profile: p) }
            }
        )
    }

    private func bindingString(_ keyPath: ReferenceWritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(
            get: { viewModel.profile?[keyPath: keyPath] ?? "system" },
            set: { v in viewModel.profile?[keyPath: keyPath] = v; try? modelContext.save() }
        )
    }

    private func saveAPIKey() {
        let key = openAIAPIKey.trimmed
        guard !key.isEmpty else { return }
        do {
            try container.keychain.save(key, for: .openAIAPIKey)
            openAIAPIKey = ""
            hasOpenAIAPIKey = true
            viewModel.profile?.useOpenAIAPI = true
            try? modelContext.save()
            PeakHaptics.success()
        } catch {
            PeakHaptics.error()
        }
    }

    private func endSession(deleteData: Bool) {
        if deleteData {
            try? viewModel.deleteAccount(modelContext: modelContext, container: container)
        } else {
            try? container.auth.signOut(modelContext: modelContext)
        }
        onSessionEnded()
    }
}

struct AchievementsGalleryView: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: AchievementCategory?

    private var filtered: [Achievement] {
        guard let selectedCategory else { return achievements }
        return achievements.filter { $0.achievementType.category == selectedCategory }
    }

    private var unlockedCount: Int { achievements.filter(\.isUnlocked).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.lg) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(unlockedCount) / \(achievements.count)")
                                .font(PeakTheme.Typography.title)
                            Text("Badges Unlocked")
                                .font(PeakTheme.Typography.caption)
                                .foregroundStyle(PeakTheme.textSecondary)
                        }
                        Spacer()
                        PeakRiveView(animation: .streakFlame, accentColor: PeakTheme.coral)
                            .frame(width: 48, height: 48)
                    }
                    .padding(.horizontal, PeakTheme.Spacing.lg)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PeakTheme.Spacing.sm) {
                            categoryChip(nil, label: "All")
                            ForEach(AchievementCategory.allCases, id: \.self) { cat in
                                categoryChip(cat, label: cat.displayName)
                            }
                        }
                        .padding(.horizontal, PeakTheme.Spacing.lg)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: PeakTheme.Spacing.lg) {
                        ForEach(filtered, id: \.id) { a in
                            VStack(spacing: PeakTheme.Spacing.xs) {
                                AchievementBadgeView(achievement: a, size: .medium)
                                Text(a.title)
                                    .font(PeakTheme.Typography.micro)
                                    .foregroundStyle(PeakTheme.textPrimary)
                                Text(a.detail)
                                    .font(PeakTheme.Typography.micro)
                                    .foregroundStyle(PeakTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                if !a.isUnlocked {
                                    ProgressView(value: a.progress)
                                        .tint(Color(hex: a.achievementType.badgeColor))
                                    Text("\(Int(a.currentValue))/\(Int(a.targetValue))")
                                        .font(PeakTheme.Typography.micro)
                                        .foregroundStyle(PeakTheme.coral)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, PeakTheme.Spacing.lg)
                }
                .padding(.vertical, PeakTheme.Spacing.lg)
            }
            .peakScreenBackground()
            .navigationTitle("Achievements")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func categoryChip(_ category: AchievementCategory?, label: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(label)
                .font(PeakTheme.Typography.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selectedCategory == category ? PeakTheme.accent.opacity(0.2) : PeakTheme.surface,
                    in: Capsule()
                )
                .foregroundStyle(selectedCategory == category ? PeakTheme.accent : PeakTheme.textSecondary)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
