import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    heroSection
                    progressRings
                    sleepCard
                    insightCard
                    achievementsSection
                    DisclaimerBanner(compact: true)
                }
                .padding(PeakTheme.Spacing.md)
            }
            .background(PeakTheme.background)
            .navigationTitle("Today")
            .refreshable {
                await viewModel.load(modelContext: modelContext, container: container)
            }
            .overlay {
                if viewModel.isLoading && viewModel.todayScore == nil {
                    LoadingView(message: "Calculating recovery...")
                }
            }
        }
        .task {
            await viewModel.load(modelContext: modelContext, container: container)
        }
    }

    private var heroSection: some View {
        PeakCard {
            VStack(spacing: PeakTheme.Spacing.md) {
                Text("Recovery Score")
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)

                RecoveryGauge(score: viewModel.todayScore?.overallScore ?? 0)

                if let explanation = viewModel.todayScore?.explanation, !explanation.isEmpty {
                    Text(explanation)
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: PeakTheme.Spacing.sm) {
                    quickActionButton(icon: "drop.fill", label: "Water") {}
                    quickActionButton(icon: "checkmark.circle", label: "Habits") {}
                    quickActionButton(icon: "heart.fill", label: "Mood") {}
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var progressRings: some View {
        HStack(spacing: PeakTheme.Spacing.lg) {
            ProgressRing(
                progress: viewModel.hydrationProgress,
                label: "Hydration",
                value: "\(Int(viewModel.hydrationProgress * 100))%",
                color: PeakTheme.teal
            )
            ProgressRing(
                progress: viewModel.habitsTotal > 0 ? Double(viewModel.habitsCompleted) / Double(viewModel.habitsTotal) : 0,
                label: "Habits",
                value: "\(viewModel.habitsCompleted)/\(viewModel.habitsTotal)",
                color: PeakTheme.coral
            )
            ProgressRing(
                progress: 0.65,
                label: "Move",
                value: "65%",
                color: PeakTheme.success
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var sleepCard: some View {
        PeakCard {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(PeakTheme.teal)
                VStack(alignment: .leading) {
                    Text("Last Night")
                        .font(PeakTheme.Typography.headline)
                    Text(sleepSummary)
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var sleepSummary: String {
        if let hours = viewModel.todayScore?.factors.sleepHours, hours > 0 {
            return String(format: "%.1f hours · Quality %.0f%%", hours, (viewModel.todayScore?.factors.sleepQuality ?? 0) * 100)
        }
        return "Sync Health data for sleep insights"
    }

    private var insightCard: some View {
        PeakCard {
            HStack(alignment: .top, spacing: PeakTheme.Spacing.md) {
                Image(systemName: "sparkles")
                    .foregroundStyle(PeakTheme.coral)
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                    Text("Daily Insight")
                        .font(PeakTheme.Typography.headline)
                    Text(viewModel.dailyInsight)
                        .font(PeakTheme.Typography.body)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var achievementsSection: some View {
        if !viewModel.recentAchievements.isEmpty {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                Text("Recent Achievements")
                    .font(PeakTheme.Typography.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PeakTheme.Spacing.sm) {
                        ForEach(viewModel.recentAchievements, id: \.id) { achievement in
                            achievementBadge(achievement)
                        }
                    }
                }
            }
        }
    }

    private func achievementBadge(_ achievement: Achievement) -> some View {
        VStack(spacing: PeakTheme.Spacing.xs) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundStyle(PeakTheme.coral)
            Text(achievement.title)
                .font(PeakTheme.Typography.micro)
                .lineLimit(1)
        }
        .padding(PeakTheme.Spacing.sm)
        .background(PeakTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
    }

    private func quickActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(PeakTheme.Typography.micro)
            }
            .foregroundStyle(PeakTheme.teal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PeakTheme.Spacing.sm)
            .background(PeakTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.sm))
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(SampleDataGenerator.previewContainer())
        .environment(\.appContainer, AppContainer())
}