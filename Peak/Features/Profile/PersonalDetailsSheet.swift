import SwiftData
import SwiftUI

struct PersonalDetailsSheet: View {
    let profile: UserProfile?
    let modelContext: ModelContext
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss


    @State private var displayName = ""
    @State private var bio = ""
    @State private var dateOfBirth = Date()
    @State private var hasDOB = false
    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 70
    @State private var gender: GenderOption = .preferNotToSay
    @State private var activity: ActivityLevel = .moderate
    @State private var units = "metric"
    @State private var recoveryTarget = 75.0
    @State private var sleepTarget = 8.0
    @State private var waterGoalML = 2500.0
    @State private var stepsGoal = 10_000.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    hero

                    detailsSection(title: "Identity", icon: "person.text.rectangle.fill", color: PeakTheme.accent) {
                        iconField("person.fill", color: PeakTheme.accent) {
                            TextField("Display name", text: $displayName)
                                .textContentType(.name)
                        }
                        Divider().opacity(0.35)
                        iconField("quote.bubble.fill", color: PeakTheme.lavender) {
                            TextField("A short bio, goals, or what motivates you", text: $bio, axis: .vertical)
                                .lineLimit(2...5)
                        }
                    }

                    detailsSection(title: "Personal Context", icon: "heart.text.square.fill", color: PeakTheme.rose) {
                        Toggle(isOn: $hasDOB) {
                            Label("Use date of birth", systemImage: "birthday.cake.fill")
                        }
                        .tint(PeakTheme.accent)
                        if hasDOB {
                            DatePicker("Birthday", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                        }
                        Divider().opacity(0.35)
                        LabeledContent {
                            Picker("Gender", selection: $gender) {
                                ForEach(GenderOption.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden()
                        } label: {
                            Label("Gender", systemImage: "person.2.fill")
                        }
                    }

                    detailsSection(title: "Body & Measurements", icon: "figure.arms.open", color: PeakTheme.mint) {
                        measurementSlider(
                            title: "Height",
                            value: displayFormatter.formatHeight(heightCm),
                            icon: "ruler.fill",
                            color: PeakTheme.mint,
                            slider: heightSlider
                        )
                        Divider().opacity(0.35)
                        measurementSlider(
                            title: "Weight",
                            value: displayFormatter.formatWeight(weightKg),
                            icon: "scalemass.fill",
                            color: PeakTheme.gold,
                            slider: weightSlider
                        )
                        if let bmi = computedBMI {
                            HStack {
                                Label("BMI estimate", systemImage: "waveform.path.ecg")
                                Spacer()
                                Text(String(format: "%.1f", bmi))
                                    .font(PeakTheme.Typography.headline)
                                    .foregroundStyle(PeakTheme.accent)
                            }
                            Text("BMI is a broad screening estimate, not a diagnosis or complete measure of health.")
                                .font(PeakTheme.Typography.micro)
                                .foregroundStyle(PeakTheme.textSecondary)
                        }
                    }

                    detailsSection(title: "Lifestyle Baseline", icon: "figure.run.circle.fill", color: PeakTheme.coral) {
                        Picker("Activity level", selection: $activity) {
                            ForEach(ActivityLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.menu)
                        Text(activity.description)
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }

                    detailsSection(title: "Core Daily Targets", icon: "scope", color: PeakTheme.ultraviolet) {
                        targetSlider("Recovery", value: "\(Int(recoveryTarget))", icon: "bolt.heart.fill", color: PeakTheme.mint, valueBinding: $recoveryTarget, range: 40...100, step: 1)
                        targetSlider("Sleep", value: "\(sleepTarget.formattedOneDecimal) h", icon: "moon.zzz.fill", color: PeakTheme.lavender, valueBinding: $sleepTarget, range: 5...10, step: 0.5)
                        targetSlider("Water", value: displayFormatter.formatWater(Int(waterGoalML)), icon: "drop.fill", color: PeakTheme.accent, valueBinding: $waterGoalML, range: 1000...5000, step: 250)
                        targetSlider("Steps", value: Int(stepsGoal).formatted(), icon: "figure.walk", color: PeakTheme.coral, valueBinding: $stepsGoal, range: 2_000...30_000, step: 500)
                    }

                    detailsSection(title: "Measurement System", icon: "ruler.fill", color: PeakTheme.sky) {
                        Picker("Preferred units", selection: $units) {
                            Label("Metric", systemImage: "globe.europe.africa.fill").tag("metric")
                            Label("Imperial", systemImage: "flag.fill").tag("imperial")
                        }
                        .pickerStyle(.segmented)
                        Text(UnitSystem(preferredUnits: units).detail)
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                }
                .padding(.horizontal, PeakTheme.Spacing.md)
                .padding(.bottom, PeakTheme.Spacing.xl)
            }
            .peakDismissKeyboardOnSwipe()
            .peakScreenBackground()
            .navigationTitle("Personal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear { load() }
        }
    }

    private var hero: some View {
        PeakCard(padding: PeakTheme.Spacing.lg) {
            HStack(spacing: PeakTheme.Spacing.md) {
                AvatarView(name: displayName.isEmpty ? "P" : displayName, avatarData: profile?.avatarData, size: 70)
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName.isEmpty ? "Your Peak profile" : displayName)
                        .font(PeakTheme.Typography.title)
                    Label(container.auth.currentProvider?.displayName ?? "Peak Account", systemImage: providerIcon)
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.accent)
                    if let email = profile?.email, !email.isEmpty {
                        Text(email)
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(PeakTheme.mint)
            }
        }
        .padding(.top, PeakTheme.Spacing.sm)
    }

    private var providerIcon: String {
        switch container.auth.currentProvider {
        case .apple: "apple.logo"
        case .google: "g.circle.fill"
        case .email: "envelope.fill"
        case nil: "person.crop.circle.badge.checkmark"
        }
    }

    @ViewBuilder
    private func detailsSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            HStack(spacing: PeakTheme.Spacing.xs) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(PeakTheme.Typography.headline)
            }
            PeakCard {
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) { content() }
            }
        }
    }

    private func iconField<Content: View>(_ icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: PeakTheme.Spacing.sm) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
            content()
        }
    }

    private var heightSlider: some View {
        Group {
            if displayFormatter.system == .metric {
                Slider(value: $heightCm, in: 120...220, step: 0.5)
            } else {
                Slider(value: Binding(get: { heightCm / 2.54 }, set: { heightCm = $0 * 2.54 }), in: 48...84, step: 0.5)
            }
        }
        .tint(PeakTheme.mint)
    }

    private var weightSlider: some View {
        Group {
            if displayFormatter.system == .metric {
                Slider(value: $weightKg, in: 40...150, step: 0.5)
            } else {
                Slider(value: Binding(get: { weightKg * 2.20462 }, set: { weightKg = $0 / 2.20462 }), in: 90...330, step: 0.5)
            }
        }
        .tint(PeakTheme.gold)
    }

    private func measurementSlider<SliderContent: View>(
        title: String,
        value: String,
        icon: String,
        color: Color,
        slider: SliderContent
    ) -> some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(value).font(PeakTheme.Typography.headline).foregroundStyle(color)
            }
            slider
        }
    }

    private func targetSlider(
        _ title: String,
        value: String,
        icon: String,
        color: Color,
        valueBinding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(title, systemImage: icon).foregroundStyle(PeakTheme.textPrimary)
                Spacer()
                Text(value).font(PeakTheme.Typography.subheadline).foregroundStyle(color)
            }
            Slider(value: valueBinding, in: range, step: step).tint(color)
        }
    }

    private var displayFormatter: UnitFormatter {
        UnitFormatter(system: UnitSystem(preferredUnits: units))
    }

    private var computedBMI: Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    private func load() {
        guard let p = profile else { return }
        displayName = p.displayName
        bio = p.bio ?? ""
        if let dob = p.dateOfBirth { dateOfBirth = dob; hasDOB = true }
        heightCm = p.heightCm > 0 ? p.heightCm : 170
        weightKg = p.weightKg > 0 ? p.weightKg : 70
        gender = p.genderOption
        activity = p.activity
        units = p.preferredUnits
        recoveryTarget = Double(p.recoveryTarget)
        sleepTarget = p.sleepHoursTarget
        waterGoalML = Double(p.dailyWaterGoalML)
        stepsGoal = Double(p.dailyStepsGoal)
    }

    private func save() {
        guard let p = profile else { return }
        p.displayName = displayName.trimmed.isEmpty ? p.displayName : displayName.trimmed
        p.bio = bio.isEmpty ? nil : bio
        p.dateOfBirth = hasDOB ? dateOfBirth : nil
        p.heightCm = heightCm
        p.weightKg = weightKg
        p.gender = gender.rawValue
        if gender != .female { p.cycleTrackingEnabled = false }
        p.activityLevel = activity.rawValue
        p.preferredUnits = units
        p.recoveryTarget = Int(recoveryTarget)
        p.sleepHoursTarget = sleepTarget
        p.dailyWaterGoalML = Int(waterGoalML)
        p.dailyStepsGoal = Int(stepsGoal)
        p.updatedAt = Date()
        try? modelContext.save()
        PeakHaptics.success()
        dismiss()
    }
}
