import SwiftData
import SwiftUI

struct LogWorkoutSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.unitPreferences) private var units
    @State private var workoutType: WorkoutType = .running
    @State private var durationMinutes: Double = 30
    @State private var intensity: WorkoutIntensity = .moderate
    @State private var calories = ""
    @State private var distance = ""
    @State private var note = ""
    @State private var customName = ""
    let date: Date

    init(date: Date = .now) {
        self.date = date
    }

    private var estimatedCalories: Int {
        Int(workoutType.kcalPerMinute * durationMinutes * intensity.multiplier)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Type") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(WorkoutType.allCases) { type in
                            Button {
                                workoutType = type
                                PeakHaptics.selection()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                        .font(.title2)
                                    Text(type.displayName)
                                        .font(PeakTheme.Typography.micro)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(workoutType == type ? Color(hex: type.color).opacity(0.2) : PeakTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.sm))
                                .foregroundStyle(workoutType == type ? Color(hex: type.color) : PeakTheme.textSecondary)
                            }
                        }
                    }
                }

                Section("Details") {
                    TextField("Custom name (optional)", text: $customName)
                    VStack(alignment: .leading) {
                        Text("Duration: \(Int(durationMinutes)) min")
                        Slider(value: $durationMinutes, in: 5...180, step: 5)
                            .tint(PeakTheme.coral)
                    }
                    Picker("Intensity", selection: $intensity) {
                        ForEach(WorkoutIntensity.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    HStack {
                        Text("Est. Calories")
                        Spacer()
                        Text("~\(estimatedCalories) kcal")
                            .foregroundStyle(PeakTheme.coral)
                    }
                }

                Section("Optional Metrics") {
                    HStack {
                        Text("Calories burned")
                        Spacer()
                        TextField("Auto", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("0", text: $distance)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text(units.formatter.distanceUnitLabel).foregroundStyle(PeakTheme.textSecondary)
                    }
                    TextField("Notes", text: $note, axis: .vertical)
                        .lineLimit(2...3)
                }
            }
            .scrollContentBackground(.hidden)
            .peakScreenBackground()
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        let kcal = Double(calories).map { $0 } ?? Double(estimatedCalories)
        let workout = WorkoutLog(
            name: customName.isEmpty ? workoutType.displayName : customName,
            workoutType: workoutType,
            durationMinutes: durationMinutes,
            caloriesBurned: kcal,
            distanceKm: units.formatter.parseDistanceInput(Double(distance) ?? 0),
            intensity: intensity,
            note: note.isEmpty ? nil : note,
            date: date
        )
        modelContext.insert(workout)
        try? modelContext.save()
        AchievementService.evaluateAll(modelContext: modelContext)
        PeakHaptics.success()
        dismiss()
    }
}
