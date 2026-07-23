import SwiftUI
import UIKit

enum PeakAppIcon: String, CaseIterable, Identifiable {
    case primary
    case orbit
    case prism

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primary: "Nexcode Glass"
        case .orbit: "Nexcode Orbit"
        case .prism: "Nexcode Prism"
        }
    }

    var detail: String {
        switch self {
        case .primary: "The signature liquid-glass Peak mark"
        case .orbit: "Connected health data in motion"
        case .prism: "A sharper performance-focused finish"
        }
    }

    var previewAsset: String {
        switch self {
        case .primary: "AppIconPreviewPrimary"
        case .orbit: "AppIconPreviewOrbit"
        case .prism: "AppIconPreviewPrism"
        }
    }

    var alternateIconName: String? {
        switch self {
        case .primary: nil
        case .orbit: "NexcodeOrbit"
        case .prism: "NexcodePrism"
        }
    }

    static var current: PeakAppIcon {
        switch UIApplication.shared.alternateIconName {
        case "NexcodeOrbit": .orbit
        case "NexcodePrism": .prism
        default: .primary
        }
    }
}

@MainActor
enum PeakAppIconManager {
    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    static func apply(_ icon: PeakAppIcon) async throws {
        guard supportsAlternateIcons else {
            throw PeakError.invalidInput("Alternate app icons are not available on this device.")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

struct AppIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected = PeakAppIcon.current
    @State private var isApplying = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                        Text("Choose your signal")
                            .font(PeakTheme.Typography.title)
                        Text("Your icon changes on the Home Screen while your data and settings stay exactly the same.")
                            .font(PeakTheme.Typography.body)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }

                    ForEach(PeakAppIcon.allCases) { icon in
                        Button {
                            apply(icon)
                        } label: {
                            HStack(spacing: PeakTheme.Spacing.md) {
                                Image(icon.previewAsset)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 76, height: 76)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: .black.opacity(0.20), radius: 12, y: 7)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(icon.displayName)
                                        .font(PeakTheme.Typography.headline)
                                    Text(icon.detail)
                                        .font(PeakTheme.Typography.caption)
                                        .foregroundStyle(PeakTheme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()
                                Image(systemName: selected == icon ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(selected == icon ? PeakTheme.mint : PeakTheme.textSecondary)
                            }
                            .padding(PeakTheme.Spacing.md)
                            .glassCard(
                                tint: selected == icon ? PeakTheme.accent.opacity(0.14) : nil,
                                interactive: true
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isApplying)
                    }

                    if !PeakAppIconManager.supportsAlternateIcons {
                        Text("Icon switching is not available on this device configuration.")
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                }
                .padding(PeakTheme.Spacing.lg)
            }
            .peakScreenBackground()
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isApplying { ProgressView().controlSize(.large) }
            }
            .alert("Couldn’t Change Icon", isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    private func apply(_ icon: PeakAppIcon) {
        guard selected != icon else { return }
        isApplying = true
        Task {
            defer { isApplying = false }
            do {
                try await PeakAppIconManager.apply(icon)
                selected = icon
                PeakHaptics.success()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
