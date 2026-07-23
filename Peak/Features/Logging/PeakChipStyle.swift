// PeakChipStyle.swift
// Provides a chip-like ButtonStyle used in LogWaterSheet

import SwiftUI

/// A simple chip button style that highlights when selected.
public struct PeakChipStyle: ButtonStyle {
    public var isSelected: Bool

    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(minWidth: 44)
            .background(backgroundColor(configuration: configuration))
            .foregroundStyle(foregroundColor(configuration: configuration))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor(configuration: configuration), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    // MARK: - Theming helpers

    private var cornerRadius: CGFloat {
        // Use PeakTheme.Radius.sm if available; fallback to 10
        #if canImport(SwiftUI)
        return (Mirror(reflecting: PeakTheme.Radius.self).children.first { $0.label == "sm" }?.value as? CGFloat) ?? 10
        #else
        return 10
        #endif
    }

    private func backgroundColor(configuration: Configuration) -> some ShapeStyle {
        // Prefer PeakTheme colors when available
        if isSelected {
            return (PeakTheme.teal.opacity(0.15) as any ShapeStyle)
        } else {
            return (PeakTheme.surfaceElevated as any ShapeStyle)
        }
    }

    private func foregroundColor(configuration: Configuration) -> some ShapeStyle {
        if isSelected {
            return (PeakTheme.teal as any ShapeStyle)
        } else {
            return (PeakTheme.textSecondary as any ShapeStyle)
        }
    }

    private func borderColor(configuration: Configuration) -> Color {
        if isSelected {
            return PeakTheme.teal.opacity(0.35)
        } else {
            return Color.secondary.opacity(0.2)
        }
    }
}
