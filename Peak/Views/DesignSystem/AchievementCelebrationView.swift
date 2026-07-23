import SwiftUI

/// Full-screen celebration when a badge unlocks — Rive burst with haptics.
struct AchievementCelebrationView: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: PeakTheme.Spacing.lg) {
                Text("Achievement Unlocked")
                    .font(PeakTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(PeakTheme.gold)
                    .textCase(.uppercase)
                    .tracking(1.2)

                ZStack {
                    PeakRiveView(
                        animation: .achievementUnlock,
                        accentColor: Color(hex: achievement.achievementType.badgeColor)
                    )
                        .frame(width: 140, height: 140)

                    AchievementBadgeView(achievement: achievement, size: .large)
                        .scaleEffect(appeared ? 1 : 0.4)
                        .opacity(appeared ? 1 : 0)
                }

                VStack(spacing: PeakTheme.Spacing.xs) {
                    Text(achievement.title)
                        .font(PeakTheme.Typography.title)
                        .foregroundStyle(PeakTheme.textPrimary)
                    Text(achievement.detail)
                        .font(PeakTheme.Typography.body)
                        .foregroundStyle(PeakTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Button("Continue") { dismiss() }
                    .buttonStyle(PeakPrimaryButtonStyle())
                    .padding(.horizontal, PeakTheme.Spacing.xl)
            }
            .padding(PeakTheme.Spacing.xl)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: PeakTheme.Radius.xl, style: .continuous))
            .padding(PeakTheme.Spacing.lg)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            PeakHaptics.success()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                appeared = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
    }
}

/// Compact card showing progress toward the next badge.
struct AchievementProgressCard: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: PeakTheme.Spacing.md) {
            AchievementBadgeView(achievement: achievement, size: .small)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.title)
                        .font(PeakTheme.Typography.subheadline)
                        .foregroundStyle(PeakTheme.textPrimary)
                    Spacer()
                    Text(achievement.achievementType.category.displayName)
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(PeakTheme.surfaceElevated, in: Capsule())
                }

                Text(achievement.detail)
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
                    .lineLimit(1)

                ProgressView(value: achievement.progress)
                    .tint(Color(hex: achievement.achievementType.badgeColor))

                Text("\(Int(achievement.currentValue)) / \(Int(achievement.targetValue))")
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.coral)
            }
        }
        .padding(PeakTheme.Spacing.sm)
        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: Color(hex: achievement.achievementType.badgeColor).opacity(0.035))
    }
}
