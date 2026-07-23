import SwiftUI

struct MetricTile: View {
    let icon: String
    let label: String
    let value: String
    let unit: String?
    var color: Color = PeakTheme.teal
    var trend: String?

    var body: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
            HStack(spacing: PeakTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(label)
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
                Spacer()
                if let trend {
                    Text(trend)
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.mint)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(PeakTheme.Typography.stat)
                    .foregroundStyle(PeakTheme.textPrimary)
                if let unit {
                    Text(unit)
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
        }
        .padding(PeakTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: color.opacity(0.035))
        .overlay(
            RoundedRectangle(cornerRadius: PeakTheme.Radius.md)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}
