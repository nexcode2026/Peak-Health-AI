import SwiftUI

struct DisclaimerBanner: View {
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: PeakTheme.Spacing.xs) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(PeakTheme.textSecondary)

            Text(compact
                 ? "Wellness tool — not medical advice."
                 : PeakConstants.medicalDisclaimer)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PeakTheme.Spacing.sm)
        .background(PeakTheme.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.sm))
        .accessibilityLabel(PeakConstants.medicalDisclaimer)
    }
}