import SwiftUI

/// Premium SwiftUI fallback when a `.riv` file is not bundled yet.
struct RiveFallbackView: View {
    let animation: PeakRiveAnimation
    var progress: Double?
    var accentColor: SwiftUI.Color = PeakTheme.accent

    @State private var pulse = false
    @State private var spin = false
    @State private var celebrate = false

    var body: some View {
        Group {
            switch animation {
            case .recoveryGauge, .progressRing:
                progressRingFallback
            case .habitCheck:
                habitCheckFallback
            case .achievementUnlock:
                achievementFallback
            case .sleepStages:
                sleepFallback
            case .hydrationSplash:
                hydrationFallback
            case .streakFlame:
                flameFallback
            case .launchLogo:
                launchFallback
            }
        }
        .onAppear { startAnimations() }
    }

    private var normalizedProgress: Double {
        min(1, max(0, (progress ?? 0) / 100))
    }

    private var progressRingFallback: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.15), lineWidth: 8)
            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.9, dampingFraction: 0.8), value: normalizedProgress)
            Image(systemName: animation.fallbackSymbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(accentColor)
                .scaleEffect(pulse ? 1.05 : 0.95)
        }
    }

    private var habitCheckFallback: some View {
        ZStack {
            Circle()
                .fill(PeakTheme.mint.opacity(0.2))
                .scaleEffect(celebrate ? 1.2 : 0.6)
                .opacity(celebrate ? 0 : 0.8)
            Image(systemName: "checkmark")
                .font(.title.weight(.bold))
                .foregroundStyle(PeakTheme.mint)
                .scaleEffect(celebrate ? 1 : 0.3)
        }
    }

    private var achievementFallback: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(PeakTheme.gold)
                    .offset(
                        x: cos(Double(i) * .pi / 3) * (celebrate ? 28 : 8),
                        y: sin(Double(i) * .pi / 3) * (celebrate ? 28 : 8)
                    )
                    .opacity(celebrate ? 1 : 0.2)
            }
            Image(systemName: "star.fill")
                .font(.largeTitle)
                .foregroundStyle(PeakTheme.gold)
                .scaleEffect(celebrate ? 1.15 : 0.85)
                .rotationEffect(.degrees(celebrate ? 12 : -12))
        }
    }

    private var sleepFallback: some View {
        HStack(spacing: 6) {
            sleepBar(height: 0.35, color: PeakTheme.midnight)
            sleepBar(height: 0.55, color: PeakTheme.lavender)
            sleepBar(height: 0.8, color: PeakTheme.accent)
            sleepBar(height: 0.5, color: PeakTheme.lavender)
            sleepBar(height: 0.25, color: PeakTheme.midnight)
        }
        .frame(height: 48)
    }

    private func sleepBar(height: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color.opacity(0.85))
            .frame(width: 10, height: 48 * height * (pulse ? 1.05 : 0.95))
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double.random(in: 0...0.4)), value: pulse)
    }

    private var hydrationFallback: some View {
        ZStack {
            Circle()
                .fill(PeakTheme.accent.opacity(0.15))
                .scaleEffect(pulse ? 1.1 : 0.9)
            Image(systemName: "drop.fill")
                .font(.title)
                .foregroundStyle(PeakTheme.accent)
                .offset(y: pulse ? -2 : 2)
        }
    }

    private var flameFallback: some View {
        Image(systemName: "flame.fill")
            .font(.title)
            .foregroundStyle(PeakTheme.coral)
            .scaleEffect(pulse ? 1.12 : 0.92)
            .shadow(color: PeakTheme.coral.opacity(0.5), radius: pulse ? 10 : 2)
    }

    private var launchFallback: some View {
        Image(systemName: "mountain.2.fill")
            .font(.system(size: 44, weight: .semibold))
            .foregroundStyle(PeakTheme.accentGradient)
            .scaleEffect(pulse ? 1.06 : 0.94)
            .rotationEffect(.degrees(spin ? 2 : -2))
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulse = true
        }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            spin = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            celebrate = true
        }
    }
}