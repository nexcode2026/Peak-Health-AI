import SwiftUI

// MARK: - Rive-like motion primitives (native SwiftUI)

/// Subtle animated mesh background
struct AnimatedMeshBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let colors: [Color] = [
                    PeakTheme.electricBlue.opacity(0.10), PeakTheme.ultraviolet.opacity(0.09),
                    PeakTheme.teal.opacity(0.07), PeakTheme.plasma.opacity(0.045),
                ]
                for i in 0..<4 {
                    let x = size.width * (0.16 + 0.25 * CGFloat(i)) + CGFloat(sin(t * 0.18 + Double(i) * 1.7)) * 44
                    let y = size.height * (0.16 + 0.20 * CGFloat(i)) + CGFloat(cos(t * 0.14 + Double(i) * 1.2)) * 38
                    let diameter = max(size.width, 320) * (i.isMultiple(of: 2) ? 0.72 : 0.54)
                    let rect = CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)
                    context.fill(Path(ellipseIn: rect), with: .color(colors[i]))
                }

                var grid = Path()
                let step: CGFloat = 44
                stride(from: CGFloat.zero, through: size.width, by: step).forEach { x in
                    grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: CGFloat.zero, through: size.height, by: step).forEach { y in
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(PeakTheme.accent.opacity(0.018)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Pulsing live-sync indicator
struct LiveSyncBadge: View {
    let isLive: Bool
    let lastSync: Date?
    var hasWatch: Bool = false
    var sources: [String] = []

    @State private var pulse = false

    var body: some View {
        HStack(spacing: PeakTheme.Spacing.xs) {
            ZStack {
                if isLive {
                    Circle()
                        .fill(PeakTheme.mint.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .scaleEffect(pulse ? 1.4 : 1)
                        .opacity(pulse ? 0 : 0.8)
                }
                Circle()
                    .fill(isLive ? PeakTheme.mint : PeakTheme.textSecondary.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(isLive ? "Live Sync" : "Paused")
                    .font(PeakTheme.Typography.micro)
                    .fontWeight(.semibold)
                    .foregroundStyle(isLive ? PeakTheme.mint : PeakTheme.textSecondary)
                if let lastSync {
                    Text(lastSync, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
            HStack(spacing: 4) {
                if hasWatch || sources.contains(where: { $0.localizedCaseInsensitiveContains("Watch") }) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PeakTheme.accent)
                        .symbolEffect(.pulse, options: isLive ? .repeating : .default)
                }
                Image(systemName: "iphone")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PeakTheme.accent)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassCapsule(tint: isLive ? PeakTheme.mint.opacity(0.12) : nil)
        .onAppear {
            guard isLive else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

/// Animated number counter
struct AnimatedCounter: View {
    let value: Int
    var font: Font = PeakTheme.Typography.stat

    var body: some View {
        Text("\(value)")
            .font(font)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
    }
}

/// Tappable card with spring press + navigation
struct TappableMetricCard<Destination: View, Content: View>: View {
    let destination: Destination
    @ViewBuilder let content: () -> Content
    @State private var pressed = false

    var body: some View {
        NavigationLink(destination: destination) {
            content()
                .scaleEffect(pressed ? 0.97 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

/// Compact day controls shared by Today and Journal. The calendar is deliberately
/// embedded here so every date-driven screen behaves the same way.
struct DayNavigator: View {
    @Binding var selectedDate: Date
    var latestDate: Date = .now
    var compact = false
    @State private var showsCalendar = false

    private var day: Date { selectedDate.startOfDay }
    private var latestDay: Date { latestDate.startOfDay }
    private var canMoveForward: Bool { day < latestDay }

    var body: some View {
        Group {
            if compact {
                compactControls
            } else {
                fullControls
            }
        }
        .sheet(isPresented: $showsCalendar) { calendarSheet }
    }

    private var fullControls: some View {
        HStack(spacing: PeakTheme.Spacing.sm) {
            dayButton(systemName: "chevron.left", label: "Previous day") {
                move(by: -1)
            }

            Button {
                showsCalendar = true
                PeakHaptics.selection()
            } label: {
                HStack(spacing: PeakTheme.Spacing.sm) {
                    ZStack {
                        Circle().fill(PeakTheme.accent.opacity(0.13))
                        Image(systemName: day.isToday ? "sun.max.fill" : "calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PeakTheme.accent)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(day.isToday ? "Today" : day.formatted(.dateTime.weekday(.wide)))
                            .font(PeakTheme.Typography.subheadline)
                            .foregroundStyle(PeakTheme.textPrimary)
                        Text(day.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
                .padding(.horizontal, PeakTheme.Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.accent.opacity(0.05), interactive: true)
            .accessibilityLabel("Choose date, currently \(day.formatted(date: .complete, time: .omitted))")

            dayButton(systemName: "chevron.right", label: "Next day", disabled: !canMoveForward) {
                move(by: 1)
            }
        }
    }

    private var compactControls: some View {
        HStack(spacing: 6) {
            compactDayButton(systemName: "chevron.left", label: "Previous day") { move(by: -1) }

            Button {
                showsCalendar = true
                PeakHaptics.selection()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: day.isToday ? "sun.max.fill" : "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PeakTheme.accent)
                    Text(day.isToday ? "Today" : day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(PeakTheme.Typography.caption)
                        .fontWeight(.semibold)
                    Text(day.formatted(.dateTime.month(.abbreviated).day()))
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassCapsule(tint: PeakTheme.accent.opacity(0.06), interactive: true)
            .accessibilityLabel("Choose date, currently \(day.formatted(date: .complete, time: .omitted))")

            compactDayButton(systemName: "chevron.right", label: "Next day", disabled: !canMoveForward) { move(by: 1) }
        }
    }

    private var calendarSheet: some View {
        NavigationStack {
            VStack(spacing: PeakTheme.Spacing.lg) {
                DatePicker(
                    "View a day",
                    selection: Binding(
                        get: { day },
                        set: { selectedDate = min($0.startOfDay, latestDay) }
                    ),
                    in: ...latestDay,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(PeakTheme.accent)
                .padding(PeakTheme.Spacing.md)
                .glassCard(tint: PeakTheme.accent.opacity(0.05))

                Button("Jump to Today") {
                    selectedDate = latestDay
                    showsCalendar = false
                    PeakHaptics.selection()
                }
                .buttonStyle(PeakPrimaryButtonStyle())
            }
            .padding(PeakTheme.Spacing.md)
            .peakScreenBackground()
            .navigationTitle("Health Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsCalendar = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func dayButton(
        systemName: String,
        label: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(disabled ? PeakTheme.textSecondary.opacity(0.35) : PeakTheme.accent)
                .frame(width: 44, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: PeakTheme.Radius.md, interactive: !disabled)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private func compactDayButton(
        systemName: String,
        label: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(disabled ? PeakTheme.textSecondary.opacity(0.3) : PeakTheme.accent)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassCapsule(interactive: !disabled)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private func move(by days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: day) else { return }
        selectedDate = min(date.startOfDay, latestDay)
        PeakHaptics.selection()
    }
}

/// Staggered card entrance
struct CardAppearModifier: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.06)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func cardAppear(index: Int = 0) -> some View {
        modifier(CardAppearModifier(index: index))
    }
}

/// Breathing glow behind recovery gauge
struct BreathingGlow: View {
    let color: Color
    var size: CGFloat = 240
    @State private var scale: CGFloat = 1

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.35), color.opacity(0)],
                    center: .center,
                    startRadius: size * 0.08,
                    endRadius: size * 0.5
                )
            )
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    scale = 1.15
                }
            }
    }
}

/// Chevron row for drill-down lists (Bevel style)
struct DrillDownRow: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    var color: Color = PeakTheme.accent

    var body: some View {
        HStack(spacing: PeakTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PeakTheme.Typography.subheadline)
                    .foregroundStyle(PeakTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
            Spacer()
            Text(value)
                .font(PeakTheme.Typography.headline)
                .foregroundStyle(PeakTheme.textPrimary)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PeakTheme.textSecondary.opacity(0.5))
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: color.opacity(0.035), interactive: true)
    }
}
