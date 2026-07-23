import SwiftUI

#if canImport(RiveRuntime)
import RiveRuntime
#endif

/// Hosts a Rive animation when the `.riv` asset exists; otherwise renders a polished SwiftUI fallback.
struct PeakRiveView: View {
    let animation: PeakRiveAnimation
    var progress: Double?
    var autoplay: Bool = true
    var accentColor: SwiftUI.Color = PeakTheme.accent

    var body: some View {
        Group {
            #if canImport(RiveRuntime)
            if PeakRiveAnimationLoader.canLoad(animation) {
                RiveHostedView(animation: animation, autoplay: autoplay)
            } else {
                RiveFallbackView(animation: animation, progress: progress, accentColor: accentColor)
            }
            #else
            RiveFallbackView(animation: animation, progress: progress, accentColor: accentColor)
            #endif
        }
        .accessibilityHidden(true)
    }
}

#if canImport(RiveRuntime)
/// Uses RiveRuntime's SwiftUI `RiveViewModel.view()` helper.
private struct RiveHostedView: View {
    @StateObject private var viewModel: RiveViewModel

    init(animation: PeakRiveAnimation, autoplay: Bool) {
        _viewModel = StateObject(
            wrappedValue: RiveViewModel(
                fileName: animation.fileName,
                fit: .contain,
                alignment: .center,
                autoPlay: autoplay
            )
        )
    }

    var body: some View {
        viewModel.view()
    }
}
#endif

/// Recovery score ring — Rive when available, animated SwiftUI otherwise.
struct PremiumRecoveryGauge: View {
    let score: Int
    var size: CGFloat = 200

    var body: some View {
        ZStack {
            if PeakRiveAnimationLoader.canLoad(.recoveryGauge) {
                PeakRiveView(
                    animation: PeakRiveAnimation.recoveryGauge,
                    progress: Double(score),
                    accentColor: PeakTheme.recoveryColor(for: score)
                )
                .frame(width: size, height: size)
            } else {
                RecoveryGauge(score: score, size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Animated progress ring for habits, hydration, etc.
struct PremiumProgressRing: View {
    let progress: Double
    let label: String
    let value: String
    var color: SwiftUI.Color = PeakTheme.teal
    var size: CGFloat = 64

    var body: some View {
        VStack(spacing: PeakTheme.Spacing.xs) {
            ZStack {
                if PeakRiveAnimationLoader.canLoad(.progressRing) {
                    PeakRiveView(
                        animation: PeakRiveAnimation.progressRing,
                        progress: progress * 100,
                        accentColor: color
                    )
                    .frame(width: size, height: size)
                    Text(value)
                        .font(PeakTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(PeakTheme.textPrimary)
                } else {
                    ProgressRingCore(progress: progress, value: value, color: color, size: size)
                }
            }
            Text(label)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
        }
        .frame(width: max(size, 76), height: size + 24, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
