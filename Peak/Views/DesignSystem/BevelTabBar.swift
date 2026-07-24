import SwiftUI

// MARK: - Bevel-inspired floating tab bar
// Permanent pill tab bar with glass material, icon + label, center Journal emphasis.

enum PeakTab: Int, CaseIterable, Identifiable {
    case today = 0
    case journal = 1
    case trends = 2
    case coach = 3
    case you = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .journal: return "Journal"
        case .trends: return "Fitness"
        case .coach: return "Coach"
        case .you: return "You"
        }
    }

    var icon: String {
        switch self {
        case .today: return "circle.hexagongrid.fill"
        case .journal: return "square.and.pencil"
        case .trends: return "figure.strengthtraining.traditional"
        case .coach: return "sparkles"
        case .you: return "person.crop.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today: return "circle.hexagongrid.fill"
        case .journal: return "square.and.pencil"
        case .trends: return "figure.strengthtraining.traditional"
        case .coach: return "sparkles"
        case .you: return "person.crop.circle.fill"
        }
    }
}

struct BevelTabBar: View {
    @Binding var selectedTab: PeakTab
    @Namespace private var tabAnimation

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: PeakTheme.Spacing.xs) {
                    tabBarContent
                        // The capsule is visual chrome; only the five explicit buttons
                        // should participate in hit testing. Interactive glass on the
                        // parent could consume the first tap after a scroll gesture.
                        .glassEffect(.regular.tint(PeakTheme.accent.opacity(0.06)), in: Capsule())
                }
            } else {
                tabBarContent
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: PeakTheme.midnight.opacity(0.15), radius: 20, y: 8)
                            .overlay { Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5) }
                    }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var tabBarContent: some View {
        HStack(spacing: 0) {
            ForEach(PeakTab.allCases.filter { $0 != .you }) { tab in tabButton(tab) }
        }
        .frame(width: 268)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
    }

    private func tabButton(_ tab: PeakTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
            PeakHaptics.selection()
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(PeakTheme.accent.opacity(0.16))
                            .matchedGeometryEffect(id: "tabHighlight", in: tabAnimation)
                            .frame(width: tab == .journal ? 44 : 38, height: 26)
                            .shadow(color: PeakTheme.accent.opacity(0.22), radius: 10)
                    }
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: tab == .journal ? 17 : 16, weight: isSelected ? .semibold : .regular))
                        .symbolEffect(.bounce, value: isSelected)
                        .foregroundStyle(isSelected ? PeakTheme.accent : PeakTheme.textSecondary)
                }
                .frame(height: 26)

                Text(tab.title)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? PeakTheme.accent : PeakTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .zIndex(isSelected ? 2 : 1)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
