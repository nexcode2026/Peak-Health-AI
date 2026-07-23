import SwiftData
import SwiftUI

struct ExpandedGoalsSheet: View {
    let profile: UserProfile?
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var recovery = 75
    @State private var water = 2500
    @State private var sleep = 8.0
    @State private var steps = 10_000
    @State private var calories = 2200
    @State private var protein = 120
    @State private var weeklyWorkouts = 4
    @State private var activeMinutes = 30
    @State private var restingHR = 60

    private var formatter: UnitFormatter {
        UnitFormatter(system: UnitSystem(preferredUnits: profile?.preferredUnits ?? "metric"))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    goalsHero

                    goalSection(
                        title: "Recovery & Sleep",
                        subtitle: "Set the baseline Peak uses to shape your daily readiness plan.",
                        icon: "bolt.heart.fill",
                        color: PeakTheme.lavender
                    ) {
                        goalControl("Recovery target", value: "\(recovery)", icon: "heart.circle.fill", color: PeakTheme.mint, binding: intBinding($recovery), range: 50...95, step: 1)
                        goalControl("Sleep duration", value: "\(sleep.formattedOneDecimal) hours", icon: "moon.zzz.fill", color: PeakTheme.lavender, binding: $sleep, range: 6...10, step: 0.25)
                        goalControl("Resting heart rate", value: "\(restingHR) bpm", icon: "waveform.path.ecg", color: PeakTheme.coral, binding: intBinding($restingHR), range: 45...80, step: 1)
                    }

                    goalSection(
                        title: "Nutrition & Hydration",
                        subtitle: formatter.system == .imperial ? "Water is shown in US customary cups." : "Water is shown in milliliters.",
                        icon: "leaf.fill",
                        color: PeakTheme.gold
                    ) {
                        goalControl("Daily water", value: formatter.formatWater(water), icon: "drop.fill", color: PeakTheme.accent, binding: intBinding($water), range: 1500...5000, step: 250)
                        goalControl("Energy target", value: "\(calories) kcal", icon: "flame.fill", color: PeakTheme.gold, binding: intBinding($calories), range: 1200...4000, step: 50)
                        goalControl("Protein target", value: "\(protein) g", icon: "bolt.fill", color: PeakTheme.coral, binding: intBinding($protein), range: 50...250, step: 5)
                    }

                    goalSection(
                        title: "Movement & Training",
                        subtitle: "Balance everyday movement with intentional training volume.",
                        icon: "figure.run",
                        color: PeakTheme.coral
                    ) {
                        goalControl("Daily steps", value: steps.formatted(), icon: "shoeprints.fill", color: PeakTheme.mint, binding: intBinding($steps), range: 3000...20_000, step: 500)
                        goalControl("Active minutes", value: "\(activeMinutes) min/day", icon: "timer", color: PeakTheme.sky, binding: intBinding($activeMinutes), range: 10...120, step: 5)
                        goalControl("Training frequency", value: "\(weeklyWorkouts) workouts/week", icon: "dumbbell.fill", color: PeakTheme.lavender, binding: intBinding($weeklyWorkouts), range: 1...7, step: 1)
                    }

                    Text("These are wellness targets, not medical recommendations. Adjust them to match guidance from your healthcare or fitness professional.")
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(PeakTheme.Spacing.md)
                .padding(.bottom, PeakTheme.Spacing.xl)
            }
            .peakScreenBackground()
            .navigationTitle("Your Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { load() }
        }
    }

    private var goalsHero: some View {
        PeakCard(padding: PeakTheme.Spacing.lg) {
            HStack(spacing: PeakTheme.Spacing.lg) {
                MetricGauge(
                    progress: Double(recovery) / 100,
                    value: "\(recovery)",
                    label: "Recovery",
                    color: PeakTheme.recoveryColor(for: recovery),
                    size: 126
                )
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                    Label("Your Peak Blueprint", systemImage: "sparkles")
                        .font(PeakTheme.Typography.headline)
                        .foregroundStyle(PeakTheme.accent)
                    Text("Nine connected targets")
                        .font(PeakTheme.Typography.title)
                    Text("Recovery, sleep, fuel, hydration and activity goals work together across Today and Coach.")
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func goalSection<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            HStack(spacing: PeakTheme.Spacing.sm) {
                ZStack {
                    Circle().fill(color.opacity(0.14))
                    Image(systemName: icon).foregroundStyle(color)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(PeakTheme.Typography.headline)
                    Text(subtitle)
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
            PeakCard {
                VStack(spacing: PeakTheme.Spacing.lg) { content() }
            }
        }
    }

    private func goalControl(
        _ title: String,
        value: String,
        icon: String,
        color: Color,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(spacing: PeakTheme.Spacing.sm) {
            HStack(spacing: PeakTheme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color.opacity(0.13))
                    Image(systemName: icon).font(.caption).foregroundStyle(color)
                }
                .frame(width: 34, height: 34)
                Text(title).font(PeakTheme.Typography.subheadline)
                Spacer()
                Text(value)
                    .font(PeakTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
            Slider(value: binding, in: range, step: step)
                .tint(color)
                .onChange(of: binding.wrappedValue) { _, _ in PeakHaptics.selection() }
        }
    }

    private func intBinding(_ value: Binding<Int>) -> Binding<Double> {
        Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0.rounded()) }
        )
    }

    private func load() {
        guard let p = profile else { return }
        recovery = p.recoveryTarget
        water = p.dailyWaterGoalML
        sleep = p.sleepHoursTarget
        steps = p.dailyStepsGoal
        calories = p.dailyCalorieGoal
        protein = p.dailyProteinGoalG
        weeklyWorkouts = p.weeklyWorkoutGoal
        activeMinutes = p.dailyActiveMinutesGoal
        restingHR = p.restingHRTarget
    }

    private func save() {
        guard let p = profile else { return }
        p.recoveryTarget = recovery
        p.dailyWaterGoalML = water
        p.sleepHoursTarget = sleep
        p.dailyStepsGoal = steps
        p.dailyCalorieGoal = calories
        p.dailyProteinGoalG = protein
        p.weeklyWorkoutGoal = weeklyWorkouts
        p.dailyActiveMinutesGoal = activeMinutes
        p.restingHRTarget = restingHR
        p.updatedAt = Date()
        try? modelContext.save()
        PeakHaptics.success()
        dismiss()
    }
}
