import SwiftUI

/// Bevel-style pillar card for the Today grid — fills available column width.
struct TodayPillarCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    var progress: Double?
    var isPrimary: Bool = false

    private let cardHeight: CGFloat = 152

    var body: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PeakTheme.textSecondary.opacity(0.35))
            }

            Text(value)
                .font(PeakTheme.Typography.stat)
                .foregroundStyle(PeakTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .font(PeakTheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(PeakTheme.textPrimary)
                .lineLimit(1)

            Text(subtitle)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 28, alignment: .topLeading)

            Spacer(minLength: 0)

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.15))
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * min(1, max(0, progress)))
                    }
                }
                .frame(height: 4)
            } else {
                Color.clear.frame(height: 4)
            }
        }
        .padding(PeakTheme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .leading)
        .glassCard(
            cornerRadius: PeakTheme.Radius.lg,
            tint: color.opacity(isPrimary ? 0.10 : 0.045),
            interactive: true
        )
        .shadow(color: color.opacity(isPrimary ? 0.16 : 0.08), radius: 14, y: 7)
    }
}

/// Mini score ring for pillar cards
struct MiniScoreRing: View {
    let score: Int
    let color: Color
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 5)
            Circle()
                .trim(from: 0, to: Double(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
        }
        .frame(width: size, height: size)
    }
}

/// Factor breakdown bar used in expanded Today sections.
struct FactorBar: View {
    let label: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)
                Spacer()
                Text("\(Int(score))")
                    .font(PeakTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(1, score / 100))
                }
            }
            .frame(height: 6)
        }
    }
}

#Preview("Pillar Cards") {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            TodayPillarCard(
                title: "Recovery",
                value: "82",
                subtitle: "Peak Ready",
                icon: "bolt.heart.fill",
                color: PeakTheme.mint,
                progress: 0.82,
                isPrimary: true
            )
            TodayPillarCard(
                title: "Strain",
                value: "64%",
                subtitle: "420 active kcal",
                icon: "flame.fill",
                color: PeakTheme.coral,
                progress: 0.64
            )
        }
        .padding()
    }
    .peakPreviewShell()
}
