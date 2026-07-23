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
            .background(PeakTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.lg))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}