import SwiftData
import SwiftUI

struct OnboardingView: View {
    private enum WellnessFocus: String, CaseIterable, Identifiable {
        case sleep = "Sleep Better"
        case recovery = "Improve Recovery"
        case movement = "Move More"
        case nutrition = "Build Nutrition"
        case hydration = "Stay Hydrated"
        case stress = "Manage Stress"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .sleep: "moon.zzz.fill"
            case .recovery: "bolt.heart.fill"
            case .movement: "figure.run"
            case .nutrition: "leaf.fill"
            case .hydration: "drop.fill"
            case .stress: "brain.head.profile"
            }
        }
    }

    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var step = 0
    @State private var displayName = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var gender: GenderOption = .preferNotToSay
    @State private var activity: ActivityLevel = .moderate
    @State private var heightCm = 175.0
    @State private var weightKg = 75.0
    @State private var unitSystem: UnitSystem = .metric
    @State private var selectedFocus: Set<WellnessFocus> = [.recovery, .sleep, .hydration]
    @State private var recoveryTarget = PeakConstants.Defaults.recoveryTarget
    @State private var waterGoal = PeakConstants.Defaults.dailyWaterML
    @State private var sleepTarget = PeakConstants.Defaults.sleepHoursTarget
    @State private var stepsGoal = PeakConstants.Defaults.dailyStepsGoal
    @State private var calorieGoal = PeakConstants.Defaults.dailyCalorieGoal
    @State private var proteinGoal = PeakConstants.Defaults.dailyProteinGoalG
    @State private var workoutGoal = PeakConstants.Defaults.weeklyWorkoutGoal
    @State private var appearance: AppearancePreference = .system
    @State private var notificationsEnabled = true
    @State private var hydrationReminderHours = 2
    @State private var windDownHour = 21
    @State private var loadSampleData = false
    @State private var enableFaceID = false
    @State private var error: PeakError?
    @State private var isFinishing = false

    let onComplete: () -> Void
    private let totalSteps = 7
    private var formatter: UnitFormatter { UnitFormatter(system: unitSystem) }

    var body: some View {
        ZStack {
            PeakTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: personalStep
                    case 2: focusStep
                    case 3: goalsStep
                    case 4: preferencesStep
                    case 5: permissionsStep
                    default: finishStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
        .task { loadExistingProfile() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                if step > 0 {
                    Button { step -= 1 } label: { Image(systemName: "chevron.left") }
                } else {
                    Color.clear.frame(width: 28, height: 28)
                }
                Spacer()
                Text("Step \(step + 1) of \(totalSteps)")
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
                Spacer()
                Color.clear.frame(width: 28, height: 28)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PeakTheme.surfaceElevated)
                    Capsule().fill(PeakTheme.accentGradient)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps))
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, PeakTheme.Spacing.lg)
        .padding(.top, PeakTheme.Spacing.md)
    }

    private var welcomeStep: some View {
        onboardingPage(
            icon: "mountain.2.fill",
            title: "Meet Your Health, Clearly",
            subtitle: "Peak turns sleep, recovery, strain, nutrition, hydration, mood, and habits into one daily plan you can act on."
        ) {
            VStack(spacing: PeakTheme.Spacing.sm) {
                benefitRow("Private by design", icon: "lock.shield.fill")
                benefitRow("Powered by Apple Health", icon: "heart.text.square.fill")
                benefitRow("Personal goals—not generic targets", icon: "scope")
                Button("Personalize Peak") { step = 1 }
                    .buttonStyle(PeakPrimaryButtonStyle())
            }
        }
    }

    private var personalStep: some View {
        onboardingForm(title: "Tell Peak About You", subtitle: "These details personalize units, goals, and recovery context.") {
            Section("Profile") {
                TextField("Your name", text: $displayName)
                    .textContentType(.name)
                DatePicker("Date of birth", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                Picker("Gender", selection: $gender) {
                    ForEach(GenderOption.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("Activity level", selection: $activity) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
            }
            Section("Measurement System") {
                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(unitSystem.detail).font(.caption).foregroundStyle(.secondary)
            }
            Section("Body Metrics") {
                metricSlider(title: "Height", value: formatter.formatHeight(heightCm), binding: $heightCm, range: 120...220, step: 0.5)
                metricSlider(title: "Weight", value: formatter.formatWeight(weightKg), binding: $weightKg, range: 35...200, step: 0.5)
            }
            continueButton(disabled: displayName.trimmed.count < 2)
        }
    }

    private var focusStep: some View {
        onboardingScroll(title: "What Would You Like to Improve?", subtitle: "Choose up to three. Peak will seed your daily plan and starter habits around them.") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(WellnessFocus.allCases) { focus in
                    Button { toggleFocus(focus) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: focus.icon).font(.title2)
                            Text(focus.rawValue).font(PeakTheme.Typography.caption).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92)
                        .background(selectedFocus.contains(focus) ? PeakTheme.accent.opacity(0.16) : PeakTheme.surface)
                        .foregroundStyle(selectedFocus.contains(focus) ? PeakTheme.accent : PeakTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
                        .overlay(alignment: .topTrailing) {
                            if selectedFocus.contains(focus) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(PeakTheme.accent).padding(8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("\(selectedFocus.count)/3 selected")
                .font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
            continueButton(disabled: selectedFocus.isEmpty)
        }
    }

    private var goalsStep: some View {
        onboardingForm(title: "Set Your Targets", subtitle: "Start realistic. You can refine every goal later in You.") {
            Section("Recovery & Rest") {
                metricSlider(title: "Recovery", value: "\(recoveryTarget)", binding: intBinding($recoveryTarget), range: 50...95, step: 1)
                metricSlider(title: "Sleep", value: "\(sleepTarget.formattedOneDecimal) h", binding: $sleepTarget, range: 6...10, step: 0.5)
            }
            Section("Hydration & Fuel") {
                metricSlider(title: "Water", value: formatter.formatWater(waterGoal), binding: intBinding($waterGoal), range: 1_500...4_500, step: 250)
                Stepper("Calories: \(calorieGoal) kcal", value: $calorieGoal, in: 1_200...4_500, step: 100)
                Stepper("Protein: \(proteinGoal) g", value: $proteinGoal, in: 40...300, step: 10)
            }
            Section("Movement") {
                Stepper("Steps: \(stepsGoal.formatted())", value: $stepsGoal, in: 2_000...25_000, step: 500)
                Stepper("Training: \(workoutGoal) sessions / week", value: $workoutGoal, in: 1...7)
            }
            continueButton()
        }
    }

    private var preferencesStep: some View {
        onboardingForm(title: "Make Peak Yours", subtitle: "Choose how Peak looks and when it should gently help.") {
            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { option in
                        Label(option.displayName, systemImage: option.icon).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Reminders") {
                Toggle("Enable helpful reminders", isOn: $notificationsEnabled)
                Stepper("Hydration: every \(hydrationReminderHours) hours", value: $hydrationReminderHours, in: 1...6)
                    .disabled(!notificationsEnabled)
                Stepper("Wind down: \(formattedHour(windDownHour))", value: $windDownHour, in: 18...23)
                    .disabled(!notificationsEnabled)
            }
            Section("Explore") {
                Toggle("Load sample history for instant trends", isOn: $loadSampleData)
                Text("Sample history is clearly separated from Apple Health data and can be removed later.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            continueButton()
        }
    }

    private var permissionsStep: some View {
        onboardingScroll(title: "Connect Your Health", subtitle: "You stay in control. Peak asks only for data used by features you enable.") {
            permissionRow(icon: "heart.fill", title: "Apple Health", detail: "Sleep stages, HRV, heart rate, steps, workouts, and energy")
            permissionRow(icon: "bell.fill", title: "Notifications", detail: "Hydration, habits, meals, workouts, and wind-down prompts")
            permissionRow(icon: "icloud.fill", title: "Private iCloud Sync", detail: "Your Peak profile and logs across your Apple devices")
            DisclaimerBanner()
            Button("Connect Selected Services") { Task { await requestPermissions() } }
                .buttonStyle(PeakPrimaryButtonStyle())
            Button("Continue Without Health Access") { step = 6 }
                .foregroundStyle(PeakTheme.textSecondary)
        }
    }

    private var finishStep: some View {
        onboardingScroll(title: "Your Peak Is Ready", subtitle: "Review your foundation. Everything remains editable from your profile.") {
            PeakCard {
                VStack(spacing: 12) {
                    reviewRow("Focus", value: selectedFocus.map(\.rawValue).sorted().joined(separator: ", "))
                    reviewRow("Sleep", value: "\(sleepTarget.formattedOneDecimal) hours")
                    reviewRow("Water", value: formatter.formatWater(waterGoal))
                    reviewRow("Movement", value: "\(stepsGoal.formatted()) steps · \(workoutGoal) training sessions")
                    reviewRow("Appearance", value: appearance.displayName)
                }
            }
            Toggle("Enable \(container.biometrics.biometricType) unlock", isOn: $enableFaceID)
                .tint(PeakTheme.accent)
                .disabled(!container.biometrics.isAvailable)
            Text("Your account remains required. Biometric unlock adds another private layer after sign-in.")
                .font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
            Button(isFinishing ? "Building Your Plan…" : "Enter Peak") {
                Task { await finishOnboarding() }
            }
            .buttonStyle(PeakPrimaryButtonStyle())
            .disabled(isFinishing)
            if let error {
                Text(error.localizedDescription).font(.caption).foregroundStyle(PeakTheme.error)
            }
        }
    }

    private func onboardingPage<Content: View>(icon: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: PeakTheme.Spacing.xl) {
            Spacer()
            Image(systemName: icon).font(.system(size: 70)).foregroundStyle(PeakTheme.heroGradient)
            pageTitle(title, subtitle: subtitle)
            content()
            Spacer()
        }
        .padding(PeakTheme.Spacing.lg)
    }

    private func onboardingScroll<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.lg) {
                pageTitle(title, subtitle: subtitle)
                content()
            }
            .padding(PeakTheme.Spacing.lg)
            .padding(.bottom, PeakTheme.Spacing.xl)
        }
    }

    private func onboardingForm<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        Form {
            Section { pageTitle(title, subtitle: subtitle) }
            content()
        }
        .scrollContentBackground(.hidden)
    }

    private func pageTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(PeakTheme.Typography.largeTitle)
            Text(subtitle).font(PeakTheme.Typography.body).foregroundStyle(PeakTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func continueButton(disabled: Bool = false) -> some View {
        Button("Continue") { step += 1 }
            .buttonStyle(PeakPrimaryButtonStyle())
            .disabled(disabled)
    }

    private func benefitRow(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(PeakTheme.Typography.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12).glassCard(cornerRadius: 12, tint: PeakTheme.accent.opacity(0.04))
    }

    private func metricSlider(title: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(title); Spacer(); Text(value).foregroundStyle(PeakTheme.accent) }
            Slider(value: binding, in: range, step: step).tint(PeakTheme.accent)
        }
    }

    private func intBinding(_ value: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0) })
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(PeakTheme.accent).frame(width: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(PeakTheme.Typography.headline)
                Text(detail).font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
            }
        }
        .padding().glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.accent.opacity(0.04))
    }

    private func reviewRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(PeakTheme.textSecondary)
            Spacer()
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
        }
        .font(PeakTheme.Typography.caption)
    }

    private func toggleFocus(_ focus: WellnessFocus) {
        if selectedFocus.contains(focus) { selectedFocus.remove(focus) }
        else if selectedFocus.count < 3 { selectedFocus.insert(focus) }
        PeakHaptics.selection()
    }

    private func formattedHour(_ hour: Int) -> String {
        Calendar.current.date(from: DateComponents(hour: hour))?.formatted(date: .omitted, time: .shortened) ?? "\(hour):00"
    }

    private func requestPermissions() async {
        _ = try? await container.healthKit.requestAuthorization()
        if notificationsEnabled { _ = await container.notifications.requestAuthorization() }
        await container.startHealthLiveSync()
        step = 6
    }

    private func loadExistingProfile() {
        guard let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first else { return }
        displayName = profile.displayName == "Peak User" ? "" : profile.displayName
        if let dob = profile.dateOfBirth { dateOfBirth = dob }
        gender = profile.genderOption
        activity = profile.activity
        if profile.heightCm > 0 { heightCm = profile.heightCm }
        if profile.weightKg > 0 { weightKg = profile.weightKg }
        unitSystem = UnitSystem(preferredUnits: profile.preferredUnits)
    }

    private func seedStarterHabits(owner: UserProfile) {
        let existing = (try? modelContext.fetch(FetchDescriptor<HabitDefinition>())) ?? []
        guard existing.isEmpty else { return }
        let presets: [WellnessFocus: (String, String, String)] = [
            .sleep: ("No Screens Before Bed", "moon.zzz.fill", "A29BFE"),
            .recovery: ("Morning Recovery Check-In", "bolt.heart.fill", "6C5CE7"),
            .movement: ("Walk 10 min", "figure.walk", "00B894"),
            .nutrition: ("Protein Breakfast", "fork.knife", "FF6B4A"),
            .hydration: ("Morning Water", "drop.fill", "45B7D1"),
            .stress: ("Two-Minute Breathing", "brain.head.profile", "FD79A8"),
        ]
        for (index, focus) in selectedFocus.sorted(by: { $0.rawValue < $1.rawValue }).enumerated() {
            guard let preset = presets[focus] else { continue }
            let habit = HabitDefinition(name: preset.0, icon: preset.1, colorHex: preset.2, sortOrder: index)
            habit.owner = owner
            modelContext.insert(habit)
        }
    }

    private func finishOnboarding() async {
        guard container.auth.isSignedIn, let userID = container.auth.currentUserID else {
            error = .authenticationFailed("Please sign in before completing setup.")
            return
        }
        isFinishing = true
        defer { isFinishing = false }
        do {
            let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.appleUserID == userID })
            let profile: UserProfile
            if let existing = try modelContext.fetch(descriptor).first {
                profile = existing
            } else {
                profile = UserProfile(appleUserID: userID, displayName: displayName.trimmed)
                modelContext.insert(profile)
            }
            profile.displayName = displayName.trimmed
            profile.dateOfBirth = dateOfBirth
            profile.gender = gender.rawValue
            profile.activityLevel = activity.rawValue
            profile.heightCm = heightCm
            profile.weightKg = weightKg
            profile.preferredUnits = unitSystem.rawValue
            profile.recoveryTarget = recoveryTarget
            profile.dailyWaterGoalML = waterGoal
            profile.sleepHoursTarget = sleepTarget
            profile.dailyStepsGoal = stepsGoal
            profile.dailyCalorieGoal = calorieGoal
            profile.dailyProteinGoalG = proteinGoal
            profile.weeklyWorkoutGoal = workoutGoal
            profile.darkModePreference = appearance.rawValue
            profile.notificationsEnabled = notificationsEnabled
            profile.hydrationReminderIntervalHours = hydrationReminderHours
            profile.windDownReminderHour = windDownHour
            profile.faceIDEnabled = enableFaceID
            profile.onboardingCompleted = true
            profile.updatedAt = .now
            OnboardingStorage.hasCompletedOnboarding = true
            OnboardingStorage.cloudKitSyncEnabled = true
            seedStarterHabits(owner: profile)
            if loadSampleData { SampleDataGenerator.populate(context: modelContext, profile: profile) }
            try modelContext.save()
            if notificationsEnabled { container.notifications.configure(profile: profile) }
            PeakHaptics.success()
            onComplete()
        } catch let peakError as PeakError {
            error = peakError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }
}
