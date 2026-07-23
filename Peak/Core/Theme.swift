import SwiftUI

// MARK: - Peak Design System (Bevel-inspired v1.2)

enum PeakTheme {
    // MARK: - Brand Colors
    static let accent = Color("PeakAccent")
    static let accentSecondary = Color(red: 0.55, green: 0.62, blue: 1.0)

    static let teal = Color("PeakTeal")
    static let tealDark = Color("PeakTealDark")
    static let coral = Color("PeakCoral")
    static let coralLight = Color("PeakCoralLight")
    static let background = Color("PeakBackground")
    static let surface = Color("PeakSurface")
    static let surfaceElevated = Color("PeakSurfaceElevated")
    static let textPrimary = Color("PeakTextPrimary")
    static let textSecondary = Color("PeakTextSecondary")
    static let success = Color("PeakSuccess")
    static let warning = Color("PeakWarning")
    static let error = Color("PeakError")

    static let mint = Color(red: 0.35, green: 0.88, blue: 0.72)
    static let lavender = Color(red: 0.62, green: 0.55, blue: 0.95)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.35)
    static let sky = Color(red: 0.45, green: 0.72, blue: 1.0)
    static let rose = Color(red: 1.0, green: 0.55, blue: 0.65)
    static let midnight = Color(red: 0.08, green: 0.09, blue: 0.14)
    static let slate = Color(red: 0.14, green: 0.15, blue: 0.22)
    static let electricBlue = Color(red: 0.30, green: 0.70, blue: 1.0)
    static let ultraviolet = Color(red: 0.52, green: 0.36, blue: 1.0)
    static let plasma = Color(red: 0.95, green: 0.38, blue: 0.78)

    // MARK: - Gradients
    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [accent.opacity(0.35), lavender.opacity(0.2), mint.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = LinearGradient(
        colors: [coral, gold],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let coolGradient = LinearGradient(
        colors: [mint, sky],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let sleepGradient = LinearGradient(
        colors: [lavender, accent.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let spectralGradient = LinearGradient(
        colors: [electricBlue, accent, ultraviolet, plasma],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ambientGradient = RadialGradient(
        colors: [accent.opacity(0.20), ultraviolet.opacity(0.08), .clear],
        center: .topTrailing,
        startRadius: 20,
        endRadius: 520
    )

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    // MARK: - Typography
    enum Typography {
        static let heroScore = Font.system(size: 56, weight: .bold, design: .rounded)
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let subheadline = Font.system(size: 15, weight: .medium, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let caption = Font.system(size: 13, weight: .regular, design: .default)
        static let micro = Font.system(size: 11, weight: .medium, design: .rounded)
        static let stat = Font.system(size: 24, weight: .bold, design: .rounded)
    }

    // MARK: - Recovery Helpers
    static func recoveryColor(for score: Int) -> Color {
        scoreColor(score)
    }

    static func recoveryLabel(for score: Int) -> String {
        switch score {
        case 80...100: "Peak Ready"
        case 60..<80: "Good to Go"
        case 40..<60: "Take It Easy"
        default: "Recovery Mode"
        }
    }

    static func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: mint
        case 60..<80: sky
        case 40..<60: gold
        default: coral
        }
    }
}

// MARK: - View Modifiers

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = PeakTheme.Radius.lg
    var tint: Color? = nil
    var interactive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular.tint(tint).interactive(interactive),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                }
        }
    }
}

struct GlassCapsuleModifier: ViewModifier {
    var tint: Color? = nil
    var interactive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6) }
        }
    }
}

struct PeakScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            PeakTheme.background.ignoresSafeArea()
            PeakTheme.ambientGradient.ignoresSafeArea()
            AnimatedMeshBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            content
        }
    }
}

/// Standard content insets — respects notch / Dynamic Island and tab bar.
struct PeakContentInsetsModifier: ViewModifier {
    var bottomTabBarPadding: CGFloat = 100

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.top, PeakTheme.Spacing.xs)
            .padding(.bottom, bottomTabBarPadding)
    }
}

struct ElevatedCardModifier: ViewModifier {
    var cornerRadius: CGFloat = PeakTheme.Radius.lg

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(PeakTheme.accent.opacity(0.025)),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .shadow(color: PeakTheme.midnight.opacity(0.12), radius: 18, y: 10)
        } else {
            content
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.28), PeakTheme.accent.opacity(0.10), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                }
                .shadow(color: PeakTheme.midnight.opacity(0.12), radius: 18, y: 10)
        }
    }
}

struct PeakPrimaryButtonStyle: ButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *) {
            configuration.label
                .font(PeakTheme.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .glassEffect(
                    .regular.tint(PeakTheme.accent).interactive(),
                    in: RoundedRectangle(cornerRadius: PeakTheme.Radius.md, style: .continuous)
                )
                .scaleEffect(configuration.isPressed ? 0.975 : 1)
                .animation(.spring(response: 0.25), value: configuration.isPressed)
        } else {
            configuration.label
                .font(PeakTheme.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PeakTheme.accentGradient, in: RoundedRectangle(cornerRadius: PeakTheme.Radius.md, style: .continuous))
                .opacity(configuration.isPressed ? 0.85 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.spring(response: 0.25), value: configuration.isPressed)
        }
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = PeakTheme.Radius.lg,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassCapsuleModifier(tint: tint, interactive: interactive))
    }

    func peakCard(cornerRadius: CGFloat = PeakTheme.Radius.lg) -> some View {
        modifier(ElevatedCardModifier(cornerRadius: cornerRadius))
    }

    func peakScreenBackground() -> some View {
        modifier(PeakScreenBackgroundModifier())
    }

    func peakContentInsets(bottomTabBarPadding: CGFloat = 100) -> some View {
        modifier(PeakContentInsetsModifier(bottomTabBarPadding: bottomTabBarPadding))
    }

    func peakButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PeakTheme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func peakChip(isSelected: Bool) -> some View {
        self
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? AnyShapeStyle(PeakTheme.accentGradient) : AnyShapeStyle(Color(.tertiarySystemFill)),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .primary)
    }
}
