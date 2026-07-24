import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = InsightsViewModel()
    @State private var selectedRecoveryDate: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    rangePicker
                    FitnessTrainingDashboard()
                    overviewHero
                    metricCards
                    recoveryChart
                    recoveryDrivers
                    readinessMix
                    habitHeatmap
                    moodChart
                    insightsList
                    achievementsGrid
                }
                .padding(.horizontal, PeakTheme.Spacing.md)
                .peakContentInsets()
            }
            .peakDismissKeyboardOnSwipe()
            .peakScreenBackground()
            .navigationTitle("Fitness")
        }
        .onAppear {
            viewModel.load(modelContext: modelContext, tier: container.currentTier)
        }
        .onChange(of: viewModel.selectedRange) { _, _ in
            viewModel.load(modelContext: modelContext, tier: container.currentTier)
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $viewModel.selectedRange) {
            ForEach(InsightsViewModel.InsightRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var overviewHero: some View {
        PeakCard(padding: PeakTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your \(viewModel.selectedRange.days)-day signal")
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(viewModel.averageRecovery.map(String.init) ?? "—")
                                .font(PeakTheme.Typography.heroScore)
                                .foregroundStyle(PeakTheme.scoreColor(viewModel.averageRecovery ?? 0))
                            Text("avg recovery")
                                .font(PeakTheme.Typography.caption)
                                .foregroundStyle(PeakTheme.textSecondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Label(
                            "\(viewModel.analytics.loggingStreak)-day data streak",
                            systemImage: "flame.fill"
                        )
                        .foregroundStyle(PeakTheme.coral)
                        Label(
                            "\(Int(viewModel.dataCoverage * 100))% coverage",
                            systemImage: "chart.bar.fill"
                        )
                        .foregroundStyle(PeakTheme.accent)
                    }
                    .font(PeakTheme.Typography.micro)
                }

                if let best = viewModel.analytics.bestDay {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(PeakTheme.gold)
                        Text("Best day: \(best.date.formatted(date: .abbreviated, time: .omitted)) at \(Int(best.recovery))")
                            .font(PeakTheme.Typography.caption)
                        Spacer()
                    }
                    .padding(PeakTheme.Spacing.sm)
                    .background(PeakTheme.gold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.sm))
                }
            }
        }
    }

    private var metricCards: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: PeakTheme.Spacing.sm
        ) {
            NavigationLink {
                RecoveryTrendDetailView(
                    average: viewModel.averageRecovery,
                    scores: viewModel.recoveryScores
                )
            } label: {
                metricCard(
                    title: "Avg Recovery",
                    value: viewModel.averageRecovery.map { "\($0)" } ?? "—",
                    trend: trend(for: viewModel.analytics.trendDelta)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                MoodTrendDetailView(
                    average: viewModel.averageMood,
                    reflections: viewModel.moodEntries
                )
            } label: {
                metricCard(
                    title: "Avg Mood",
                    value: viewModel.averageMood.map { String(format: "%.1f", $0) } ?? "—",
                    trend: .neutral
                )
            }
            .buttonStyle(.plain)

            metricCard(
                title: "Habit Rate",
                value: "\(Int(viewModel.habitAdherenceRate * 100))%",
                trend: viewModel.habitAdherenceRate >= 0.75 ? .up : .neutral
            )

            metricCard(
                title: "Stability",
                value: viewModel.analytics.consistencyScore.map { "\($0)" } ?? "—",
                trend: (viewModel.analytics.consistencyScore ?? 0) >= 75 ? .up : .neutral
            )
        }
    }

    private enum Trend { case up, down, neutral }

    private func trend(for delta: Double?) -> Trend {
        guard let delta else { return .neutral }
        if delta > 2 { return .up }
        if delta < -2 { return .down }
        return .neutral
    }

    private func metricCard(title: String, value: String, trend: Trend) -> some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                Text(title)
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)
                HStack {
                    Text(value)
                        .font(PeakTheme.Typography.title)
                    Image(systemName: trend == .up ? "arrow.up.right" : trend == .down ? "arrow.down.right" : "minus")
                        .font(.caption)
                        .foregroundStyle(trend == .up ? PeakTheme.success : trend == .down ? PeakTheme.coral : PeakTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recoveryChart: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                Text("Recovery Trend")
                    .font(PeakTheme.Typography.headline)

                if viewModel.recoveryScores.isEmpty {
                    Text("No data yet")
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                        .frame(height: 180)
                } else {
                    Chart(viewModel.recoveryScores, id: \.id) { score in
                        AreaMark(
                            x: .value("Date", score.date),
                            y: .value("Score", score.overallScore)
                        )
                        .foregroundStyle(PeakTheme.teal.opacity(0.3))

                        LineMark(
                            x: .value("Date", score.date),
                            y: .value("Score", score.overallScore)
                        )
                        .foregroundStyle(PeakTheme.teal)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", score.date),
                            y: .value("Score", score.overallScore)
                        )
                        .foregroundStyle(PeakTheme.teal)
                        .symbolSize(selectedRecoveryScore?.id == score.id ? 80 : 18)

                        if selectedRecoveryScore?.id == score.id {
                            RuleMark(x: .value("Selected", score.date))
                                .foregroundStyle(PeakTheme.textSecondary.opacity(0.5))
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                    VStack(spacing: 1) {
                                        Text("\(score.overallScore)")
                                            .font(PeakTheme.Typography.headline)
                                        Text(score.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(PeakTheme.Typography.micro)
                                    }
                                    .padding(6)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                }
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXSelection(value: $selectedRecoveryDate)
                    .frame(height: 180)
                }
            }
        }
    }

    private var selectedRecoveryScore: RecoveryScore? {
        guard let selectedRecoveryDate else { return nil }
        return viewModel.recoveryScores.min {
            abs($0.date.timeIntervalSince(selectedRecoveryDate)) <
                abs($1.date.timeIntervalSince(selectedRecoveryDate))
        }
    }

    private var recoveryDrivers: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                HStack {
                    Text("Recovery Drivers")
                        .font(PeakTheme.Typography.headline)
                    Spacer()
                    Text("association")
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }

                if viewModel.analytics.drivers.isEmpty {
                    Text("Log at least three days with matching recovery factors to reveal your strongest signals.")
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                } else {
                    ForEach(viewModel.analytics.drivers) { driver in
                        HStack(spacing: PeakTheme.Spacing.sm) {
                            Image(systemName: driver.driver.icon)
                                .foregroundStyle(driverColor(driver.driver))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(driver.driver.rawValue)
                                        .font(PeakTheme.Typography.caption)
                                    Spacer()
                                    Text("\(driver.coefficient >= 0 ? "+" : "")\(driver.coefficient, specifier: "%.2f")")
                                        .font(PeakTheme.Typography.micro)
                                        .foregroundStyle(driver.coefficient >= 0 ? PeakTheme.mint : PeakTheme.coral)
                                }
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(PeakTheme.surfaceElevated)
                                        Capsule()
                                            .fill(driverColor(driver.driver))
                                            .frame(width: geometry.size.width * abs(driver.coefficient))
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                    }
                    Text("Correlation highlights patterns; it does not establish cause.")
                        .font(.system(size: 9))
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
        }
    }

    private func driverColor(_ driver: RecoveryDriver) -> Color {
        switch driver {
        case .sleep: PeakTheme.lavender
        case .hydration: PeakTheme.accent
        case .mood: PeakTheme.rose
        case .habits: PeakTheme.mint
        }
    }

    private var readinessMix: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                Text("Readiness Mix")
                    .font(PeakTheme.Typography.headline)
                if viewModel.recoveryScores.isEmpty {
                    Text("Recovery zones appear after your first score.")
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                } else {
                    HStack(spacing: PeakTheme.Spacing.lg) {
                        Chart(viewModel.analytics.zones) { zone in
                            SectorMark(
                                angle: .value("Days", zone.count),
                                innerRadius: .ratio(0.62),
                                angularInset: 2
                            )
                            .foregroundStyle(PeakTheme.scoreColor(zone.lowerBound))
                            .cornerRadius(3)
                        }
                        .frame(width: 110, height: 110)

                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(viewModel.analytics.zones) { zone in
                                HStack {
                                    Circle()
                                        .fill(PeakTheme.scoreColor(zone.lowerBound))
                                        .frame(width: 8, height: 8)
                                    Text(zone.id)
                                        .font(PeakTheme.Typography.caption)
                                    Spacer()
                                    Text("\(zone.count)d")
                                        .font(PeakTheme.Typography.caption)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var habitHeatmap: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                Text("Habit Adherence")
                    .font(PeakTheme.Typography.headline)

                Chart(viewModel.habitAdherence) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Rate", day.rate * 100)
                    )
                    .foregroundStyle(PeakTheme.coral.gradient)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 120)
            }
        }
    }

    private var moodChart: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                Text("Mood Distribution")
                    .font(PeakTheme.Typography.headline)

                if viewModel.moodEntries.isEmpty {
                    Text("Log moods in Track to see distribution")
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                } else {
                    let distribution = Dictionary(grouping: viewModel.moodEntries, by: \.moodRating)
                    Chart(1...5, id: \.self) { rating in
                        BarMark(
                            x: .value("Mood", rating),
                            y: .value("Count", distribution[rating]?.count ?? 0)
                        )
                        .foregroundStyle(PeakTheme.teal)
                    }
                    .frame(height: 120)
                }
            }
        }
    }

    private var insightsList: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                Text("Personalized Insights")
                    .font(PeakTheme.Typography.headline)

                ForEach(viewModel.personalizedInsights) { insight in
                    HStack(alignment: .top, spacing: PeakTheme.Spacing.sm) {
                        Image(systemName: insight.icon)
                            .foregroundStyle(insightColor(insight.sentiment))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(insight.title)
                                .font(PeakTheme.Typography.subheadline)
                            Text(insight.detail)
                                .font(PeakTheme.Typography.caption)
                                .foregroundStyle(PeakTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func insightColor(_ sentiment: InsightsViewModel.InsightFinding.Sentiment) -> Color {
        switch sentiment {
        case .positive: PeakTheme.mint
        case .attention: PeakTheme.coral
        case .neutral: PeakTheme.accent
        }
    }

    private var achievementsGrid: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            Text("Achievements")
                .font(PeakTheme.Typography.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: PeakTheme.Spacing.sm) {
                ForEach(viewModel.achievements, id: \.id) { achievement in
                    VStack(spacing: PeakTheme.Spacing.xs) {
                        Image(systemName: achievement.icon)
                            .font(.title)
                            .foregroundStyle(achievement.isUnlocked ? PeakTheme.coral : PeakTheme.textSecondary.opacity(0.4))
                        Text(achievement.title)
                            .font(PeakTheme.Typography.micro)
                            .multilineTextAlignment(.center)
                        if !achievement.isUnlocked {
                            ProgressView(value: achievement.progress)
                                .tint(PeakTheme.coral)
                        }
                    }
                    .padding(PeakTheme.Spacing.sm)
                    .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.coral.opacity(0.03))
                    .opacity(achievement.isUnlocked ? 1 : 0.7)
                }
            }
        }
    }
}

#Preview {
    InsightsView()
        .peakPreviewShell()
}
