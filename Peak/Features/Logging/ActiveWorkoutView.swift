import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitPreferences) private var units
    @Environment(\.dismiss) private var dismiss

    private var tracker: WorkoutTrackingService { container.workoutTracker }

    private let trackableTypes: [WorkoutType] = [.walking, .running, .cycling]

    var body: some View {
        NavigationStack {
            ZStack {
                PeakTheme.background.ignoresSafeArea()

                if tracker.state == .idle {
                    workoutTypePicker
                } else {
                    activeTrackingView
                }
            }
            .navigationTitle(tracker.state == .idle ? "Start Training" : tracker.workoutType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tracker.state == .idle ? "Close" : "Cancel") {
                        if tracker.state == .idle {
                            dismiss()
                        } else {
                            tracker.cancel()
                        }
                    }
                }
            }
        }
    }

    private var workoutTypePicker: some View {
        VStack(spacing: PeakTheme.Spacing.lg) {
            Text("Track walks, runs, and rides with GPS & motion sensors")
                .font(PeakTheme.Typography.body)
                .foregroundStyle(PeakTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !tracker.isLocationAuthorized {
                Button("Enable Location Access") {
                    tracker.requestPermissions()
                }
                .buttonStyle(PeakPrimaryButtonStyle())
                .padding(.horizontal)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(trackableTypes, id: \.self) { type in
                    Button {
                        tracker.requestPermissions()
                        tracker.start(workoutType: type)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: type.icon).font(.title)
                            Text(type.displayName).font(PeakTheme.Typography.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: Color(hex: type.color).opacity(0.04), interactive: true)
                    }
                    .foregroundStyle(Color(hex: type.color))
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, PeakTheme.Spacing.lg)
    }

    private var activeTrackingView: some View {
        VStack(spacing: PeakTheme.Spacing.xl) {
            Text(formatElapsed(tracker.elapsedSeconds))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PeakTheme.textPrimary)

            HStack(spacing: PeakTheme.Spacing.lg) {
                statBlock(title: "Distance", value: units.formatter.formatDistance(tracker.distanceKm))
                statBlock(title: "Steps", value: "\(tracker.steps)")
                if let pace = tracker.currentPaceMinPerKm, pace > 0 {
                    statBlock(
                        title: "Pace",
                        value: units.system == .metric
                            ? String(format: "%.1f min/km", pace)
                            : String(format: "%.1f min/mi", pace * 1.60934)
                    )
                }
            }
            .padding(.horizontal)

            HStack(spacing: PeakTheme.Spacing.md) {
                if tracker.state == .tracking {
                    Button("Pause") { tracker.pause() }
                        .buttonStyle(PeakChipStyle(isSelected: false))
                } else {
                    Button("Resume") { tracker.resume() }
                        .buttonStyle(PeakChipStyle(isSelected: true))
                }

                Button("Finish") {
                    _ = tracker.stop(modelContext: modelContext)
                    dismiss()
                }
                .buttonStyle(PeakPrimaryButtonStyle())
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, PeakTheme.Spacing.xl)
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(PeakTheme.Typography.stat)
                .foregroundStyle(PeakTheme.textPrimary)
            Text(title)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
