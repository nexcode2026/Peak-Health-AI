import Charts
import SwiftData
import SwiftUI

// MARK: - Recovery Detail

struct RecoveryDetailView: View {
    let score: Int
    let snapshot: DailyHealthSnapshot?
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showMoodLog = false
    @State private var showWaterLog = false

    private var formatter: UnitFormatter {
        UnitFormatter(system: UnitSystem(preferredUnits: profiles.first?.preferredUnits ?? "metric"))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    BreathingGlow(color: PeakTheme.scoreColor(score), size: 200)
                    RecoveryGauge(score: score, size: 180)
                }
                .padding(.top, 8)

                VStack(spacing: 4) {
                    Text(recoveryLabel)
                        .font(.title2.bold())
                    Text("Composite of sleep, HRV, activity, hydration, mood & habits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                if let snap = snapshot {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        factorCard("Sleep", value: "\(Int(snap.sleepHours))h", weight: "30%", color: PeakTheme.lavender)
                        factorCard("HRV", value: snap.hrvMs.map { "\(Int($0))ms" } ?? "—", weight: "25%", color: PeakTheme.mint)
                        factorCard("Activity", value: "\(snap.steps)", weight: "15%", color: PeakTheme.sky)
                        factorCard("Hydration", value: formatter.formatWater(Int(snap.hydrationMl)), weight: "10%", color: PeakTheme.accent)
                        factorCard("Mood", value: snap.moodScore.map { "\($0)/10" } ?? "—", weight: "10%", color: PeakTheme.rose)
                        factorCard("Habits", value: "\(Int(snap.habitCompletionRate * 100))%", weight: "10%", color: PeakTheme.gold)
                    }
                    .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    Button { showMoodLog = true } label: {
                        Label("Check In", systemImage: "face.smiling.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PeakTheme.rose)

                    Button { showWaterLog = true } label: {
                        Label("Add Water", systemImage: "drop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(PeakTheme.accent)
                }
                .padding(.horizontal)

                LiveSyncSection()
                    .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
        .peakScreenBackground()
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showWaterLog) { LogWaterSheet() }
        .sheet(isPresented: $showMoodLog) {
            LogMoodSheet { rating, energy, note, tags in
                saveMood(rating: rating, energy: energy, note: note, tags: tags)
            }
        }
    }

    private func saveMood(rating: Int, energy: Int, note: String?, tags: [String]) {
        let today = Date().startOfDay
        let existing = try? modelContext.fetch(FetchDescriptor<MoodReflection>(
            predicate: #Predicate { $0.date >= today }
        )).first
        if let existing {
            existing.moodRating = rating
            existing.energyLevel = energy
            existing.note = note
            existing.tags = tags
            existing.updatedAt = .now
        } else {
            modelContext.insert(MoodReflection(moodRating: rating, energyLevel: energy, note: note, tags: tags))
        }
        try? modelContext.save()
        PeakHaptics.success()
    }

    private var recoveryLabel: String {
        switch score {
        case 80...100: "Peak Ready"
        case 60..<80: "Good to Go"
        case 40..<60: "Take It Easy"
        default: "Recovery Mode"
        }
    }

    private func factorCard(_ title: String, value: String, weight: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(weight).font(.caption2).foregroundStyle(.tertiary)
            }
            Text(value).font(.title3.bold())
        }
        .padding(14)
        .peakCard()
    }
}

// MARK: - Sleep Detail

struct SleepDetailView: View {
    let snapshot: DailyHealthSnapshot?
    let goalHours: Double
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitPreferences) private var units
    @State private var weekData: [(date: Date, hours: Double)] = []
    @State private var selectedGoal: Double = PeakConstants.Defaults.sleepHoursTarget
    @State private var displayedHours: Double = 0
    @State private var displayedQuality: Int?
    @State private var isSyncing = false
    @AppStorage("peak.sleep.windDownComplete") private var windDownComplete = false
    @AppStorage("peak.sleep.caffeineCutoffComplete") private var caffeineCutoffComplete = false
    @AppStorage("peak.sleep.screenCurfewComplete") private var screenCurfewComplete = false

    init(snapshot: DailyHealthSnapshot?, goalHours: Double = PeakConstants.Defaults.sleepHoursTarget) {
        self.snapshot = snapshot
        self.goalHours = goalHours
        _selectedGoal = State(initialValue: goalHours)
        _displayedHours = State(initialValue: snapshot?.sleepHours ?? 0)
        _displayedQuality = State(initialValue: snapshot?.sleepQuality)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: PeakTheme.Spacing.md) {
                    ZStack {
                        BreathingGlow(color: PeakTheme.lavender, size: 200)
                        MetricGauge(
                        progress: min(1, displayedHours / max(1, selectedGoal)),
                        value: displayedHours > 0 ? String(format: "%.1fh", displayedHours) : "—",
                        label: "Sleep",
                        color: PeakTheme.lavender,
                        size: 180
                        )
                    }
                    VStack(spacing: 6) {
                        Text("Last Night").font(.title2.bold())
                        Text("\(Int(min(1, displayedHours / max(1, selectedGoal)) * 100))% of your \(selectedGoal.formattedOneDecimal)h goal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let displayedQuality {
                            Label("Quality \(displayedQuality)/10", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PeakTheme.mint)
                        }
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.top, PeakTheme.Spacing.xs)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Sleep Goal").font(.headline)
                        Spacer()
                        Text("\(selectedGoal.formattedOneDecimal) hours").foregroundStyle(PeakTheme.lavender)
                    }
                    Slider(value: $selectedGoal, in: 6...10, step: 0.25)
                        .tint(PeakTheme.lavender)
                    Button("Save Sleep Goal") { saveGoal() }
                        .buttonStyle(.borderedProminent)
                        .tint(PeakTheme.lavender)
                }
                .padding()
                .peakCard()
                .padding(.horizontal)

                if let snap = snapshot, snap.deepSleepHours > 0 || snap.remSleepHours > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sleep Stages").font(.headline)
                        HStack(spacing: 12) {
                            stageBar("Deep", hours: snap.deepSleepHours, color: PeakTheme.lavender)
                            stageBar("REM", hours: snap.remSleepHours, color: PeakTheme.accent)
                            stageBar("Light", hours: max(0, snap.sleepHours - snap.deepSleepHours - snap.remSleepHours), color: PeakTheme.sky.opacity(0.6))
                        }
                    }
                    .padding()
                    .peakCard()
                    .padding(.horizontal)
                }

                if !weekData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("7-Day Trend").font(.headline)
                        Chart(weekData, id: \.date) { item in
                            BarMark(x: .value("Day", item.date, unit: .day), y: .value("Hours", item.hours))
                                .foregroundStyle(PeakTheme.sleepGradient)
                                .cornerRadius(4)
                        }
                        .frame(height: 160)
                        .chartYAxis { AxisMarks(position: .leading) }
                    }
                    .padding()
                    .peakCard()
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Tonight's Routine").font(.headline)
                    Toggle("Caffeine cutoff completed", isOn: $caffeineCutoffComplete)
                    Toggle("Start wind-down routine", isOn: $windDownComplete)
                    Toggle("Screen curfew completed", isOn: $screenCurfewComplete)
                }
                .tint(PeakTheme.lavender)
                .padding()
                .peakCard()
                .padding(.horizontal)

                tipsSection([
                    ("moon.zzz.fill", "Consistent bedtime", "Go to bed within 30 min of your target."),
                    ("thermometer.medium", "Cool room", "\(units.formatter.formatTemperature(18))–\(units.formatter.formatTemperature(20)) supports deeper sleep."),
                    ("iphone.slash", "Screen curfew", "Avoid screens 1 hour before bed.")
                ])
            }
            .padding(.bottom, 100)
        }
        .peakScreenBackground()
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await syncSleep() } } label: {
                    if isSyncing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                }
                .disabled(isSyncing)
            }
        }
        .task { loadWeekData() }
    }

    private func stageBar(_ label: String, hours: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 40, height: max(20, CGFloat(hours) * 25))
            Text(label).font(.caption2)
            Text(String(format: "%.1fh", hours)).font(.caption.bold())
        }
        .frame(maxWidth: .infinity)
    }

    private func loadWeekData() {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Date().startOfDay) ?? Date().startOfDay
        let descriptor = FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date)]
        )
        let snapshots = (try? modelContext.fetch(descriptor)) ?? []
        weekData = snapshots.filter { $0.sleepHours > 0 }.map { ($0.date, $0.sleepHours) }
        if let latest = snapshots.last, latest.sleepHours > 0 {
            displayedHours = latest.sleepHours
            displayedQuality = latest.sleepQuality > 0 ? Int(latest.sleepQuality * 10) : nil
        }
    }

    private func saveGoal() {
        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            profile.sleepHoursTarget = selectedGoal
            profile.updatedAt = .now
            try? modelContext.save()
            PeakHaptics.success()
        }
    }

    private func syncSleep() async {
        isSyncing = true
        await container.healthData.refresh(modelContext: modelContext)
        loadWeekData()
        isSyncing = false
    }
}

// MARK: - Heart Detail

struct HeartDetailView: View {
    let snapshot: DailyHealthSnapshot?
    @Environment(\.appContainer) private var container

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    heartCard("Resting HR", value: snapshot?.restingHeartRate.map { "\(Int($0))" } ?? "—", unit: "bpm", color: PeakTheme.coral)
                    heartCard("HRV", value: snapshot?.hrvMs.map { "\(Int($0))" } ?? "—", unit: "ms", color: PeakTheme.mint)
                }
                .padding(.horizontal)

                if let live = container.liveSync.liveHeartRate {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundStyle(PeakTheme.coral)
                            .symbolEffect(.pulse)
                        Text("Live from Apple Health")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(live)) bpm")
                            .font(.title3.bold())
                            .contentTransition(.numericText())
                    }
                    .padding()
                    .glassCard()
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("What affects HRV").font(.headline)
                    factorTip(icon: "bed.double.fill", title: "Sleep quality", detail: "Poor sleep lowers HRV", color: PeakTheme.lavender)
                    factorTip(icon: "figure.run", title: "Training load", detail: "Hard workouts temporarily reduce HRV", color: PeakTheme.sky)
                    factorTip(icon: "drop.fill", title: "Hydration", detail: "Dehydration impacts heart rate variability", color: PeakTheme.accent)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
        .peakScreenBackground()
        .navigationTitle("Heart")
        .navigationBarTitleDisplayMode(.large)
    }

    private func heartCard(_ title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 36, weight: .bold, design: .rounded))
                Text(unit).font(.subheadline).foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .peakCard()
    }
}

// MARK: - Activity Detail

struct ActivityDetailView: View {
    let snapshot: DailyHealthSnapshot?
    @Environment(\.appContainer) private var container
    @Environment(\.unitPreferences) private var units
    @State private var showWorkoutLog = false

    private var steps: Int {
        container.liveSync.liveSteps > 0 ? container.liveSync.liveSteps : (snapshot?.steps ?? 0)
    }

    private var strainProgress: Double {
        let stepProgress = Double(steps) / 10_000
        let exerciseProgress = (snapshot?.exerciseMinutes ?? 0) / 30
        let activeProgress = container.liveSync.liveActiveCalories / 500
        return min(1, max(0, stepProgress * 0.45 + exerciseProgress * 0.35 + activeProgress * 0.20))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    BreathingGlow(color: PeakTheme.coral, size: 200)
                    MetricGauge(
                        progress: strainProgress,
                        value: "\(Int(strainProgress * 100))%",
                        label: "Strain",
                        color: PeakTheme.coral,
                        size: 180
                    )
                }
                .padding(.top, PeakTheme.Spacing.xs)

                Text("Activity load from steps, exercise minutes and active energy")
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricTile("Active Cal", value: "\(Int(container.liveSync.liveActiveCalories))", icon: "flame.fill", color: PeakTheme.coral)
                    metricTile("Exercise", value: snapshot.map { String(format: "%.0f min", $0.exerciseMinutes) } ?? "—", icon: "figure.run", color: PeakTheme.mint)
                    metricTile("Distance", value: snapshot.map { units.formatter.formatDistance($0.distanceKm) } ?? "—", icon: "map.fill", color: PeakTheme.sky)
                    metricTile("VO₂ Max", value: snapshot?.vo2Max.map { String(format: "%.1f", $0) } ?? "—", icon: "lungs.fill", color: PeakTheme.lavender)
                }
                .padding(.horizontal)

                Button { showWorkoutLog = true } label: {
                    Label("Log a Workout", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PeakTheme.coral)
                .padding(.horizontal)

                LiveSyncSection()
                    .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
        .peakScreenBackground()
        .navigationTitle("Strain & Activity")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showWorkoutLog) { LogWorkoutSheet() }
    }

    private func metricTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .peakCard()
    }
}

// MARK: - Nutrition Detail

struct NutritionDetailView: View {
    let snapshot: DailyHealthSnapshot?
    @State private var showFoodLog = false

    private var calorieProgress: Double {
        min(1, max(0, (snapshot?.caloriesConsumed ?? 0) / max(1, snapshot?.calorieGoal ?? 2200)))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    BreathingGlow(color: PeakTheme.gold, size: 200)
                    MetricGauge(
                        progress: calorieProgress,
                        value: "\(Int(snapshot?.caloriesConsumed ?? 0))",
                        label: "Nutrition",
                        color: PeakTheme.gold,
                        size: 180
                    )
                }
                .padding(.top, PeakTheme.Spacing.xs)

                Text("\(Int(calorieProgress * 100))% of your \(Int(snapshot?.calorieGoal ?? 2200)) kcal goal")
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)

                macroRings
                    .padding(.horizontal)

                Button { showFoodLog = true } label: {
                    Label("Log Meal or Snack", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PeakTheme.gold)
                .padding(.horizontal)

                tipsSection([
                    ("leaf.fill", "Protein timing", "Spread protein across meals for recovery."),
                    ("drop.fill", "Stay hydrated", "Drink water with every meal."),
                    ("chart.bar.fill", "Track consistently", "Log meals for better insights.")
                ])
            }
            .padding(.bottom, 100)
        }
        .peakScreenBackground()
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showFoodLog) { LogFoodSheet() }
    }

    private var macroRings: some View {
        HStack(spacing: 20) {
            macroRing("Protein", value: snapshot?.proteinGrams ?? 0, goal: 150, color: PeakTheme.coral)
            macroRing("Carbs", value: snapshot?.carbsGrams ?? 0, goal: 250, color: PeakTheme.gold)
            macroRing("Fat", value: snapshot?.fatGrams ?? 0, goal: 70, color: PeakTheme.lavender)
        }
        .padding()
        .peakCard()
    }

    private func macroRing(_ label: String, value: Double, goal: Double, color: Color) -> some View {
        MetricGauge(
            progress: min(1, value / goal),
            value: "\(Int(value))g",
            label: label,
            color: color,
            size: 76
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hydration Detail

struct HydrationDetailView: View {
    let snapshot: DailyHealthSnapshot?
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appContainer) private var container
    @State private var addedML = 0
    @State private var showCustomLog = false

    private var currentML: Int { Int(snapshot?.hydrationMl ?? 0) + addedML }
    private var goalML: Int { Int(snapshot?.hydrationGoalMl ?? 2500) }
    private var formatter: UnitFormatter {
        UnitFormatter(system: UnitSystem(preferredUnits: profiles.first?.preferredUnits ?? "metric"))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    BreathingGlow(color: PeakTheme.accent, size: 200)
                    MetricGauge(
                        progress: min(1, Double(currentML) / Double(max(1, goalML))),
                        value: formatter.formatWaterShort(currentML),
                        label: "Water · \(formatter.waterUnitLabel)",
                        color: PeakTheme.accent,
                        size: 180
                    )
                }
                .padding(.top, PeakTheme.Spacing.xs)

                Text(formatter.formatWaterGoal(goalML))
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Log").font(.headline)
                    HStack(spacing: 12) {
                        quickLogButton(250, icon: "cup.and.saucer.fill")
                        quickLogButton(500, icon: "waterbottle.fill")
                        quickLogButton(1_000, icon: "drop.fill")
                    }
                    Button("Custom Amount") { showCustomLog = true }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        .tint(PeakTheme.accent)
                }
                .padding()
                .peakCard()
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
        .peakScreenBackground()
        .navigationTitle("Hydration")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showCustomLog) { LogWaterSheet() }
    }

    private func quickLogButton(_ amountML: Int, icon: String) -> some View {
        Button {
            logWater(amountML)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundStyle(PeakTheme.accent)
                Text(formatter.formatWater(amountML)).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PeakTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func logWater(_ amountML: Int) {
        modelContext.insert(HydrationLog(amountML: amountML))
        try? modelContext.save()
        addedML += amountML
        AchievementService.evaluateAll(modelContext: modelContext)
        PeakHaptics.success()
        Task { try? await container.healthKit.writeHydration(ml: amountML, date: .now) }
    }
}

// MARK: - Trends Detail

struct RecoveryTrendDetailView: View {
    let average: Int?
    let scores: [RecoveryScore]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroMetric(
                    title: "Avg Recovery",
                    value: average.map { "\($0)" } ?? "—",
                    subtitle: "\(scores.count) days tracked",
                    gradient: PeakTheme.accentGradient
                )

                if !scores.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Scores").font(.headline)
                        Chart(scores, id: \.date) { score in
                            LineMark(
                                x: .value("Date", score.date, unit: .day),
                                y: .value("Score", score.overallScore)
                            )
                            .foregroundStyle(PeakTheme.accentGradient)
                            .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 180)
                    }
                    .padding()
                    .peakCard()
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 100)
        }
        .peakScreenBackground()
        .navigationTitle("Recovery Trend")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct MoodTrendDetailView: View {
    let average: Double?
    let reflections: [MoodReflection]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroMetric(
                    title: "Avg Mood",
                    value: average.map { String(format: "%.1f", $0) } ?? "—",
                    subtitle: "out of 5",
                    gradient: PeakTheme.warmGradient
                )

                if !reflections.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mood Log").font(.headline)
                        ForEach(reflections, id: \.id) { mood in
                            HStack {
                                Text(mood.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(mood.moodRating)/5")
                                    .font(.headline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .peakCard()
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 100)
        }
        .peakScreenBackground()
        .navigationTitle("Mood Trend")
        .navigationBarTitleDisplayMode(.large)
    }
}

private func factorTip(icon: String, title: String, detail: String, color: Color) -> some View {
    HStack(alignment: .top, spacing: 12) {
        Image(systemName: icon)
            .font(.body)
            .foregroundStyle(color)
            .frame(width: 28)
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
    .padding(.vertical, 4)
}

// MARK: - Shared Components

private struct LiveSyncSection: View {
    @Environment(\.appContainer) private var container

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apple Health").font(.headline)
            LiveSyncBadge(
                isLive: container.liveSync.isLive,
                lastSync: container.liveSync.lastSyncDate,
                hasWatch: container.liveSync.hasAppleWatch
            )
            if !container.liveSync.connectedSources.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connected sources").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(container.liveSync.connectedSources, id: \.self) { source in
                        HStack(spacing: 8) {
                            Image(systemName: source.localizedCaseInsensitiveContains("Watch") ? "applewatch" : "iphone")
                                .font(.caption)
                                .foregroundStyle(PeakTheme.accent)
                            Text(source).font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .glassCard()
    }
}

private func heroMetric(title: String, value: String, subtitle: String, gradient: LinearGradient) -> some View {
    VStack(spacing: 8) {
        Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.8))
        Text(value)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
        Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.7))
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
    .background(gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .padding(.horizontal)
}

private func tipsSection(_ tips: [(String, String, String)]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Tips").font(.headline)
        ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tip.0)
                    .font(.body)
                    .foregroundStyle(PeakTheme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tip.1).font(.subheadline.weight(.semibold))
                    Text(tip.2).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
    .padding()
    .peakCard()
    .padding(.horizontal)
}

// MARK: - Complete health monitoring

struct HealthMonitoringView: View {
    let snapshot: DailyHealthSnapshot
    let profile: UserProfile?
    let date: Date
    @Environment(\.appContainer) private var container

    private var formatter: UnitFormatter {
        UnitFormatter(system: UnitSystem(preferredUnits: profile?.preferredUnits ?? "metric"))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PeakTheme.Spacing.lg) {
                PeakCard(padding: PeakTheme.Spacing.lg) {
                    HStack(spacing: PeakTheme.Spacing.md) {
                        ZStack {
                            Circle().fill(PeakTheme.coral.opacity(0.12))
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(PeakTheme.coral)
                        }
                        .frame(width: 66, height: 66)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Health Monitoring").font(PeakTheme.Typography.title)
                            Text(date.formatted(date: .complete, time: .omitted))
                                .font(PeakTheme.Typography.caption)
                                .foregroundStyle(PeakTheme.textSecondary)
                            Label("Apple Health · read only", systemImage: "lock.shield.fill")
                                .font(PeakTheme.Typography.micro)
                                .foregroundStyle(PeakTheme.mint)
                        }
                        Spacer()
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PeakTheme.Spacing.sm) {
                    monitorCard("Weight", value: weightValue, detail: "Latest measurement", icon: "scalemass.fill", color: PeakTheme.gold)
                    monitorCard("Heart Rate", value: snapshot.averageHeartRate.map { "\(Int($0)) bpm" } ?? "No data", detail: "Daily average", icon: "heart.fill", color: PeakTheme.coral)
                    monitorCard("Respiratory Rate", value: snapshot.respiratoryRate.map { "\(String(format: "%.1f", $0))/min" } ?? "No data", detail: "Breaths per minute", icon: "wind", color: PeakTheme.mint)
                    monitorCard("Blood Pressure", value: bloodPressureValue, detail: "Systolic / diastolic", icon: "waveform.path.ecg.rectangle.fill", color: PeakTheme.rose)
                    monitorCard("Blood Oxygen", value: snapshot.oxygenSaturation.map { "\(Int($0.rounded()))%" } ?? "No data", detail: "Oxygen saturation", icon: "lungs.fill", color: PeakTheme.sky)
                    monitorCard("Height", value: heightValue, detail: "Latest measurement", icon: "ruler.fill", color: PeakTheme.teal)
                    monitorCard("Resting Heart Rate", value: snapshot.restingHeartRate.map { "\(Int($0)) bpm" } ?? "No data", detail: "Resting baseline", icon: "heart.circle.fill", color: PeakTheme.ultraviolet)
                    monitorCard("Temperature", value: snapshot.bodyTemperatureC.map(formatter.formatTemperature) ?? "No data", detail: "Body temperature", icon: "thermometer.medium", color: PeakTheme.coral)
                    monitorCard("Sleep", value: snapshot.sleepHours > 0 ? "\(snapshot.sleepHours.formattedOneDecimal) h" : "No data", detail: "Deep \(Int(snapshot.deepSleepHours * 60))m · REM \(Int(snapshot.remSleepHours * 60))m", icon: "moon.zzz.fill", color: PeakTheme.lavender)
                }

                PeakCard {
                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                        Label("How this works", systemImage: "waveform.path.ecg.magnifyingglass")
                            .font(PeakTheme.Typography.headline)
                        Text("Peak reads the latest available measurements from Apple Health. A missing value usually means the device has not recorded that metric or Peak does not have permission to read it.")
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                        Button("Refresh Apple Health") {
                            Task { await container.liveSync.manualRefresh() }
                        }
                        .font(PeakTheme.Typography.caption).fontWeight(.semibold)
                    }
                }

                DisclaimerBanner(compact: false)
            }
            .padding(PeakTheme.Spacing.md)
            .padding(.bottom, 90)
        }
        .peakScreenBackground()
        .navigationTitle("Health Monitoring")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var weightValue: String {
        if let kg = snapshot.bodyMassKg { return formatter.formatWeight(kg) }
        if let kg = profile?.weightKg, kg > 0 { return formatter.formatWeight(kg) }
        return "No data"
    }

    private var heightValue: String {
        if let cm = snapshot.heightCm { return formatter.formatHeight(cm) }
        if let cm = profile?.heightCm, cm > 0 { return formatter.formatHeight(cm) }
        return "No data"
    }

    private var bloodPressureValue: String {
        guard let systolic = snapshot.bloodPressureSystolic,
              let diastolic = snapshot.bloodPressureDiastolic else { return "No data" }
        return "\(Int(systolic))/\(Int(diastolic)) mmHg"
    }

    private func monitorCard(_ title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Spacer()
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(title)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
            Text(value)
                .font(PeakTheme.Typography.headline)
                .foregroundStyle(PeakTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(PeakTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(PeakTheme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: color.opacity(0.055))
    }
}

// MARK: - Female-only cycle tracking

struct CycleTrackingView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @State private var showLog = false

    private var summary: CycleTrackingSummary {
        CycleTrackingSummary.make(
            entries: entries,
            averageCycleLength: profile.averageCycleLength,
            periodLength: profile.averagePeriodLength
        )
    }

    var body: some View {
        Group {
            if profile.genderOption == .female && profile.cycleTrackingEnabled {
                cycleContent
            } else {
                ContentUnavailableView(
                    "Cycle Tracking Unavailable",
                    systemImage: "lock.shield.fill",
                    description: Text("Cycle Tracking is available only for female profiles that enable it in Health Data settings.")
                )
                .peakScreenBackground()
            }
        }
        .navigationTitle("Cycle Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLog) { LogCycleEntrySheet() }
    }

    private var cycleContent: some View {
        ScrollView {
            VStack(spacing: PeakTheme.Spacing.lg) {
                PeakCard(padding: PeakTheme.Spacing.lg) {
                    HStack(spacing: PeakTheme.Spacing.lg) {
                        MetricGauge(
                            progress: Double(summary.cycleDay ?? 0) / Double(max(21, profile.averageCycleLength)),
                            value: summary.cycleDay.map(String.init) ?? "—",
                            label: "Cycle Day",
                            color: PeakTheme.rose,
                            size: 124
                        )
                        VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                            Text(summary.phase).font(PeakTheme.Typography.headline)
                            Text(summary.lastPeriodStart.map { "Last period began \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Start by logging a period day.")
                                .font(PeakTheme.Typography.caption)
                                .foregroundStyle(PeakTheme.textSecondary)
                            Text("Phase timing is an estimate, not a fertility or pregnancy prediction.")
                                .font(PeakTheme.Typography.micro)
                                .foregroundStyle(PeakTheme.warning)
                        }
                    }
                }

                Button { showLog = true } label: {
                    Label("Log Today", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .peakButtonStyle()

                cycleSettings
                recentLogs
                evidenceGuidance

                PeakCard {
                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                        Label("When to seek care", systemImage: "cross.case.fill")
                            .font(PeakTheme.Typography.headline)
                            .foregroundStyle(PeakTheme.coral)
                        Text("Contact a healthcare professional for new or severe pain, very heavy bleeding, fainting, possible pregnancy concerns, or symptoms that interrupt normal activities. Tracking can help you describe patterns, but Peak does not diagnose conditions.")
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                }
            }
            .padding(PeakTheme.Spacing.md)
            .padding(.bottom, 90)
        }
        .peakScreenBackground()
    }

    private var cycleSettings: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) {
                Label("Your baseline", systemImage: "slider.horizontal.3")
                    .font(PeakTheme.Typography.headline)
                Stepper("Average cycle · \(profile.averageCycleLength) days", value: Binding(
                    get: { profile.averageCycleLength },
                    set: { profile.averageCycleLength = $0; try? modelContext.save() }
                ), in: 21...45)
                Stepper("Average period · \(profile.averagePeriodLength) days", value: Binding(
                    get: { profile.averagePeriodLength },
                    set: { profile.averagePeriodLength = $0; try? modelContext.save() }
                ), in: 2...10)
            }
        }
    }

    @ViewBuilder
    private var recentLogs: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: "Recent Cycle Notes", icon: "calendar")
            if entries.isEmpty {
                EmptyStateView(icon: "calendar.badge.plus", title: "No cycle history yet", message: "Log bleeding, symptoms, energy, and notes to see useful patterns over time.")
            } else {
                ForEach(entries.prefix(7), id: \.id) { entry in
                    HStack(spacing: PeakTheme.Spacing.sm) {
                        Text(entry.isPeriodDay ? "🩸" : "🌿").font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(PeakTheme.Typography.subheadline).fontWeight(.semibold)
                            Text(entry.isPeriodDay ? "\(entry.flow.title) flow · Energy \(entry.energy)/5" : "Cycle note · Energy \(entry.energy)/5")
                                .font(PeakTheme.Typography.micro)
                                .foregroundStyle(PeakTheme.textSecondary)
                            if !entry.symptoms.isEmpty {
                                Text(entry.symptoms.map(\.title).joined(separator: " · "))
                                    .font(PeakTheme.Typography.micro)
                                    .foregroundStyle(PeakTheme.rose)
                            }
                        }
                        Spacer()
                    }
                    .padding(PeakTheme.Spacing.md)
                    .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.rose.opacity(0.04))
                }
            }
        }
    }

    private var evidenceGuidance: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: "Evidence-aware comfort", icon: "leaf.fill")
            guidanceCard("🚶", "Gentle movement", "Regular aerobic activity may help some people experience fewer cramps and can support mood. Adapt intensity to how you feel.")
            guidanceCard("♨️", "Comfortable heat", "A warm bath or heating pad on the abdomen can be soothing for period discomfort. Avoid temperatures that could burn skin.")
            guidanceCard("😴", "Protect sleep", "Adequate sleep before and during a period can make discomfort easier to cope with.")
            guidanceCard("📝", "Track patterns", "Record timing, flow, symptoms, and disruptions so you can share meaningful changes with a clinician.")
            HStack {
                Link("ACOG: Painful periods", destination: URL(string: "https://www.acog.org/womens-health/faqs/dysmenorrhea-painful-periods")!)
                Spacer()
                Link("Women’s Health: Cycles", destination: URL(string: "https://womenshealth.gov/menstrual-cycle/your-menstrual-cycle")!)
            }
            .font(PeakTheme.Typography.micro)
        }
    }

    private func guidanceCard(_ emoji: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: PeakTheme.Spacing.sm) {
            Text(emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PeakTheme.Typography.subheadline).fontWeight(.semibold)
                Text(detail).font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
            }
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.rose.opacity(0.035))
    }
}

private struct LogCycleEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var date = Date().startOfDay
    @State private var isPeriodDay = true
    @State private var flow: CycleFlow = .medium
    @State private var selectedSymptoms = Set<CycleSymptom>()
    @State private var energy = 3
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    PeakCard {
                        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        Toggle("Period day", isOn: $isPeriodDay).tint(PeakTheme.rose)
                        if isPeriodDay {
                            Picker("Flow", selection: $flow) {
                                ForEach(CycleFlow.allCases.filter { $0 != .none }) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                        Text("Symptoms").font(PeakTheme.Typography.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: PeakTheme.Spacing.sm) {
                            ForEach(CycleSymptom.allCases) { symptom in
                                Button {
                                    if selectedSymptoms.contains(symptom) { selectedSymptoms.remove(symptom) }
                                    else { selectedSymptoms.insert(symptom) }
                                } label: {
                                    Label(symptom.title, systemImage: selectedSymptoms.contains(symptom) ? "checkmark.circle.fill" : "circle")
                                        .font(PeakTheme.Typography.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(PeakTheme.Spacing.sm)
                                        .glassCapsule(tint: PeakTheme.rose.opacity(selectedSymptoms.contains(symptom) ? 0.14 : 0.03), interactive: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    PeakCard {
                        Stepper("Energy · \(energy)/5", value: $energy, in: 1...5)
                        TextField("Private notes", text: $notes, axis: .vertical).lineLimit(3...7)
                    }
                }
                .padding(PeakTheme.Spacing.md)
            }
            .peakScreenBackground()
            .navigationTitle("Cycle Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        let day = date.startOfDay
        let descriptor = FetchDescriptor<CycleEntry>(predicate: #Predicate { $0.date == day })
        let entry: CycleEntry
        if let existing = try? modelContext.fetch(descriptor).first {
            entry = existing
        } else {
            entry = CycleEntry(date: day)
            modelContext.insert(entry)
        }
        entry.isPeriodDay = isPeriodDay
        entry.flow = isPeriodDay ? flow : .none
        entry.symptoms = Array(selectedSymptoms)
        entry.energy = energy
        entry.notes = notes.trimmed
        try? modelContext.save()
        PeakHaptics.success()
        dismiss()
    }
}
