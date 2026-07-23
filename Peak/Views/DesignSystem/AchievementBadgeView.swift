import SwiftUI

struct AchievementBadgeView: View {
    let achievement: Achievement
    var size: BadgeSize = .medium

    enum BadgeSize {
        case small, medium, large
        var dimension: CGFloat {
            switch self {
            case .small: return 72
            case .medium: return 96
            case .large: return 120
            }
        }
    }

    var body: some View {
        VStack(spacing: PeakTheme.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(
                        achievement.isUnlocked
                            ? Color(hex: achievement.achievementType.badgeColor).opacity(0.2)
                            : PeakTheme.surfaceElevated
                    )
                    .frame(width: size.dimension, height: size.dimension)

                Image(systemName: achievement.icon)
                    .font(.system(size: size.dimension * 0.35))
                    .foregroundStyle(
                        achievement.isUnlocked
                            ? Color(hex: achievement.achievementType.badgeColor)
                            : PeakTheme.textSecondary.opacity(0.35)
                    )

                if !achievement.isUnlocked {
                    Circle()
                        .trim(from: 0, to: achievement.progress)
                        .stroke(Color(hex: achievement.achievementType.badgeColor), lineWidth: 3)
                        .rotationEffect(.degrees(-90))
                        .frame(width: size.dimension - 4, height: size.dimension - 4)
                }

                if achievement.isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(PeakTheme.gold)
                        .offset(x: size.dimension * 0.32, y: size.dimension * 0.32)
                }

                Text(achievement.achievementType.tier.displayName.prefix(1))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Color(hex: achievement.achievementType.badgeColor), in: Circle())
                    .offset(x: -size.dimension * 0.34, y: -size.dimension * 0.34)
            }

            if size != .small {
                Text(achievement.title)
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(achievement.isUnlocked ? PeakTheme.textPrimary : PeakTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .accessibilityLabel("\(achievement.title), \(achievement.isUnlocked ? "unlocked" : "\(Int(achievement.progress * 100)) percent progress")")
    }
}