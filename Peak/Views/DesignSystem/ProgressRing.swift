import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let label: String
    let value: String
    var color: Color = PeakTheme.teal
    var size: CGFloat = 64
    var lineWidth: CGFloat = 6

    var body: some View {
        VStack(spacing: PeakTheme.Spacing.xs) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(1, progress))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value)
                    .font(PeakTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(PeakTheme.textPrimary)
            }
            .frame(width: size, height: size)

            Text(label)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}