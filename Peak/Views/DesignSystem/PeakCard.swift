import SwiftUI

struct PeakCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = PeakTheme.Spacing.md

    init(padding: CGFloat = PeakTheme.Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: PeakTheme.accent.opacity(0.025))
            .shadow(color: PeakTheme.midnight.opacity(0.14), radius: 20, y: 10)
    }
}
