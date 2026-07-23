import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: PeakTheme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(PeakTheme.teal.opacity(0.6))

            VStack(spacing: PeakTheme.Spacing.xs) {
                Text(title)
                    .font(PeakTheme.Typography.title)
                    .foregroundStyle(PeakTheme.textPrimary)

                Text(message)
                    .font(PeakTheme.Typography.body)
                    .foregroundStyle(PeakTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PeakPrimaryButtonStyle())
                    .frame(maxWidth: 200)
            }
        }
        .padding(PeakTheme.Spacing.xl)
    }
}