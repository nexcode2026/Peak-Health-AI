import SwiftUI

struct ProgressRingCore: View {
    let progress: Double
    let value: String
    var color: Color = PeakTheme.teal
    var size: CGFloat = 64
    var lineWidth: CGFloat = 6
    @State private var animatedProgress = 0.0

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .padding(lineWidth * 0.75)
            Circle()
                .stroke(color.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(colors: [color.opacity(0.62), color, color.opacity(0.82)], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.26), radius: 5)
            Text(value)
                .font(PeakTheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(PeakTheme.textPrimary)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .padding(.horizontal, 8)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) {
                animatedProgress = progress.clamped(to: 0...1)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.65, dampingFraction: 0.84)) {
                animatedProgress = newValue.clamped(to: 0...1)
            }
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    let label: String
    let value: String
    var color: Color = PeakTheme.teal
    var size: CGFloat = 64
    var lineWidth: CGFloat = 6

    var body: some View {
        VStack(spacing: PeakTheme.Spacing.xs) {
            ProgressRingCore(progress: progress, value: value, color: color, size: size, lineWidth: lineWidth)

            if !label.isEmpty {
                Text(label)
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
