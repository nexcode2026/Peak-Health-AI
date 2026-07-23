import SwiftUI

struct SectionHeaderView: View {
    let title: String
    var icon: String? = nil
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            HStack(spacing: PeakTheme.Spacing.xs) {
                if let icon {
                    ZStack {
                        Circle().fill(PeakTheme.accent.opacity(0.11))
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PeakTheme.accent)
                    }
                    .frame(width: 26, height: 26)
                }
                Text(title)
                    .font(PeakTheme.Typography.headline)
                    .foregroundStyle(PeakTheme.textPrimary)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.accent)
            }
        }
    }
}
