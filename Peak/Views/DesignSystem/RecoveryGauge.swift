import SwiftUI

/// The shared Nexcode score language used by recovery, sleep, and historical metrics.
/// Keeping one ring implementation prevents the dashboard from mixing visual metaphors.
struct MetricGauge: View {
    let progress: Double
    let value: String
    let label: String
    let color: Color
    var size: CGFloat = 200

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7)
                }
                .padding(size * 0.075)

            Circle()
                .stroke(color.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.55), color, color.opacity(0.85)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.34), radius: size * 0.045)

            Circle()
                .trim(from: 0, to: min(animatedProgress, 0.12))
                .stroke(Color.white.opacity(0.78), style: StrokeStyle(lineWidth: max(2, lineWidth * 0.22), lineCap: .round))
                .rotationEffect(.degrees(-90))
                .blur(radius: 0.4)

            VStack(spacing: PeakTheme.Spacing.xxs) {
                Text(value)
                    .font(size > 150 ? PeakTheme.Typography.heroScore : PeakTheme.Typography.title)
                    .foregroundStyle(PeakTheme.textPrimary)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                Text(label)
                    .font(PeakTheme.Typography.micro)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
            .padding(.horizontal, size * 0.16)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
        .onAppear { animate(to: progress) }
        .onChange(of: progress) { _, newValue in animate(to: newValue) }
    }

    private var lineWidth: CGFloat { max(7, size * 0.07) }

    private func animate(to progress: Double) {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.82)) {
            animatedProgress = progress.clamped(to: 0...1)
        }
    }
}

struct RecoveryGauge: View {
    let score: Int
    var size: CGFloat = 200

    var body: some View {
        MetricGauge(
            progress: Double(score) / 100,
            value: "\(score)",
            label: PeakTheme.recoveryLabel(for: score),
            color: PeakTheme.recoveryColor(for: score),
            size: size
        )
    }
}
