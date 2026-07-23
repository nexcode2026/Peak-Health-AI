import SwiftData
import SwiftUI

// MARK: - Peak Preview Catalog
// Open this file in Xcode and use the Canvas (⌥⌘↩) to browse screens.

#Preview("Launch") {
    LaunchScreenView(message: "Syncing with iCloud...")
}

#Preview("Sign In") {
    SignInView(onSignedIn: {})
        .peakPreviewShell()
}

#Preview("Onboarding") {
    OnboardingView(onComplete: {})
        .peakPreviewShell()
}

#Preview("Today") {
    DashboardView()
        .peakPreviewShell()
}

#Preview("Today — Dark") {
    DashboardView()
        .peakPreviewShell()
        .preferredColorScheme(.dark)
}

#Preview("Journal") {
    TrackView()
        .peakPreviewShell()
}

#Preview("Trends") {
    InsightsView()
        .peakPreviewShell()
}

#Preview("Coach") {
    CoachView()
        .peakPreviewShell()
}

#Preview("You / Profile") {
    ProfileView()
        .peakPreviewShell()
}

#Preview("Main Tabs") {
    @Previewable @State var tab: PeakTab = .today
    MainTabView(selectedTab: $tab)
        .peakPreviewShell()
}

#Preview("Tab Bar") {
    @Previewable @State var tab: PeakTab = .today
    ZStack(alignment: .bottom) {
        PeakTheme.background.ignoresSafeArea()
        BevelTabBar(selectedTab: $tab)
    }
}

#Preview("Your Day Pillars") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
            TodayPillarCard(
                title: "Recovery",
                value: "78",
                subtitle: "Good to Go",
                icon: "bolt.heart.fill",
                color: PeakTheme.mint,
                progress: 0.78,
                isPrimary: true
            )
            TodayPillarCard(
                title: "Sleep",
                value: "7.5h",
                subtitle: "Quality 8/10",
                icon: "moon.zzz.fill",
                color: PeakTheme.lavender,
                progress: 0.94
            )
            TodayPillarCard(
                title: "Water",
                value: "1800 ml",
                subtitle: "Goal 2500 ml",
                icon: "drop.fill",
                color: PeakTheme.accent,
                progress: 0.72
            )
        }
        .padding()
    }
    .peakPreviewShell()
}

#Preview("Recovery Detail") {
    NavigationStack {
        RecoveryDetailView(score: 78, snapshot: PeakPreview.snapshot)
    }
    .peakPreviewShell()
}

#Preview("Sleep Detail") {
    NavigationStack {
        SleepDetailView(snapshot: PeakPreview.snapshot)
    }
    .peakPreviewShell()
}

#Preview("Activity Detail") {
    NavigationStack {
        ActivityDetailView(snapshot: PeakPreview.snapshot)
    }
    .peakPreviewShell()
}

#Preview("Hydration Detail") {
    NavigationStack {
        HydrationDetailView(snapshot: PeakPreview.snapshot)
    }
    .peakPreviewShell()
}

#Preview("Log Water") {
    LogWaterSheet()
        .peakPreviewShell()
}

#Preview("Log Workout") {
    LogWorkoutSheet()
        .peakPreviewShell()
}

#Preview("Track Workout") {
    ActiveWorkoutView()
        .peakPreviewShell()
}

#Preview("Personal Details") {
    PersonalDetailsSheet(profile: PeakPreview.profile, modelContext: PeakPreview.modelContext)
        .peakPreviewShell()
}

#Preview("Goals") {
    ExpandedGoalsSheet(profile: PeakPreview.profile, modelContext: PeakPreview.modelContext)
        .peakPreviewShell()
}

#Preview("Paywall") {
    PaywallView()
        .peakPreviewShell()
}

#Preview("Lock Screen") {
    LockScreenView(onUnlock: {})
        .peakPreviewShell()
}

#Preview("Design — Cards") {
    ScrollView {
        VStack(spacing: 16) {
            PeakCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Peak Card").font(PeakTheme.Typography.headline)
                    Text("Elevated surface with padding").font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
            EmptyStateView(
                icon: "figure.run",
                title: "No Workouts",
                message: "Start tracking to see activity here.",
                actionTitle: "Track Workout"
            ) {}
            DisclaimerBanner(compact: true)
            LoadingView(message: "Syncing Apple Health...")
        }
        .padding()
    }
    .peakScreenBackground()
    .peakPreviewShell()
}

#Preview("Design — Components") {
    ScrollView {
        VStack(spacing: 20) {
            ProgressRing(progress: 0.72, label: "Recovery", value: "78", color: PeakTheme.mint)
            RecoveryGauge(score: 78)
            HStack(spacing: 12) {
                MetricTile(icon: "drop.fill", label: "Water", value: "1.8L", unit: "/ 2.5L", color: PeakTheme.teal)
                MetricTile(icon: "flame.fill", label: "Calories", value: "1450", unit: "kcal", color: PeakTheme.coral)
            }
            MoodPicker(rating: .constant(4)) { _ in }
            AvatarView(name: "Alex Peak", avatarData: nil, size: 64)
        }
        .padding()
    }
    .peakScreenBackground()
    .peakPreviewShell()
}