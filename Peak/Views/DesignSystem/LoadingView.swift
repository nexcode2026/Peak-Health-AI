import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: PeakTheme.Spacing.md) {
            ProgressView()
                .tint(PeakTheme.teal)
            Text(message)
                .font(PeakTheme.Typography.caption)
                .foregroundStyle(PeakTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}