import SwiftUI

// MARK: - Peak Design System
// Premium health aesthetic: deep teal/blue, vibrant coral accent, generous spacing.

enum PeakTheme {
    // MARK: - Brand Colors
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

    // MARK: - Gradients
    static let heroGradient = LinearGradient(
        colors: [teal, tealDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [coral, coralLight],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardGradient = LinearGradient(
        colors: [surface, surfaceElevated.opacity(0.6)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Typography
    enum Typography {
        static let heroScore = Font.system(size: 72, weight: .bold, design: .rounded)
        static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let title = Font.system(.title2, design: .rounded).weight(.semibold)
        static let headline = Font.system(.headline, design: .rounded)
        static let body = Font.system(.body, design: .default)
        static let caption = Font.system(.caption, design: .default)
        static let micro = Font.system(.caption2, design: .default)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 999
    }

    // MARK: - Recovery Score Colors
    static func recoveryColor(for score: Int) -> Color {
        switch score {
        case 80...100: return success
        case 60..<80: return teal
        case 40..<60: return warning
        default: return error
        }
    }

    static func recoveryLabel(for score: Int) -> String {
        switch score {
        case 80...100: return "Peak Ready"
        case 60..<80: return "Recovering"
        case 40..<60: return "Moderate"
        default: return "Rest Needed"
        }
    }
}

// MARK: - View Modifiers

struct PeakCardStyle: ViewModifier {
    var padding: CGFloat = PeakTheme.Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PeakTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.lg))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

struct PeakPrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PeakTheme.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PeakTheme.Spacing.md)
            .background(
                isDisabled
                    ? AnyShapeStyle(Color.gray.opacity(0.4))
                    : AnyShapeStyle(PeakTheme.accentGradient)
            )
            .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func peakCard(padding: CGFloat = PeakTheme.Spacing.md) -> some View {
        modifier(PeakCardStyle(padding: padding))
    }
}