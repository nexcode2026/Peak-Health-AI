import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = InsightsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    rangePicker
                    metricCards
                    recoveryChart
                    habitHeatmap
                    moodChart
                    insightsList
                    achievementsGrid
                }
                .padding(PeakTheme.Spacing.md)
            }
            .background(PeakTheme.background)
            .navigationTitle("Insights")
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

    private var metricCards: some View {
        HStack(spacing: PeakTheme.Spacing.sm) {
            metricCard(
                title: "Avg Recovery",
                value: viewModel.averageRecovery.map { "\($0)" } ?? "—",
                trend: .up
            )
            metricCard(
                title: "Avg Mood",
                value: viewModel.averageMood.map { String(format: "%.1f", $0) } ?? "—",
                trend: .neutral
            )
        }
    }

    private enum Trend { case up, down, neutral }

    private func metricCard(title: String, value: String, trend: Trend) -> some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                Text(title)
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)
                HStack {
                    Text(value)
                        .font(PeakTheme.Typography.title)
                    Image(systemName: trend == .up ? "arrow.up.right" : "minus")
                        .font(.caption)
                        .foregroundStyle(trend == .up ? PeakTheme.success : PeakTheme.textSecondary)
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
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 180)
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

                ForEach(viewModel.personalizedInsights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: PeakTheme.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(PeakTheme.coral)
                            .font(.caption)
                        Text(insight)
                            .font(PeakTheme.Typography.body)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                }
            }
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
                    .background(PeakTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
                    .opacity(achievement.isUnlocked ? 1 : 0.7)
                }
            }
        }
    }
}

#Preview {
    InsightsView()
        .modelContainer(SampleDataGenerator.previewContainer())
        .environment(\.appContainer, AppContainer())
}