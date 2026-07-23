import SwiftUI

struct RecoveryGauge: View {
    let score: Int
    var size: CGFloat = 200
    @State private var animatedScore: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(PeakTheme.surfaceElevated, lineWidth: 14)

            Circle()
                .trim(from: 0, to: animatedScore / 100)
                .stroke(
                    PeakTheme.recoveryColor(for: score),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.2, dampingFraction: 0.8), value: animatedScore)

            VStack(spacing: PeakTheme.Spacing.xxs) {
                Text("\(score)")
                    .font(size > 150 ? PeakTheme.Typography.heroScore : PeakTheme.Typography.largeTitle)
                    .foregroundStyle(PeakTheme.textPrimary)
                    .contentTransition(.numericText())

                Text(PeakTheme.recoveryLabel(for: score))
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.recoveryColor(for: score))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recovery score \(score), \(PeakTheme.recoveryLabel(for: score))")
        .onAppear {
            animatedScore = Double(score)
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.spring(response: 1.2)) {
                animatedScore = Double(newValue)
            }
        }
    }
}