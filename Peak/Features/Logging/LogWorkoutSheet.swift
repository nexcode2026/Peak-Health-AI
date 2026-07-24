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
    @State private var exerciseDetails = ""
    @State private var sessionDate: Date
    let date: Date
    let workout: WorkoutLog?

    init(date: Date = .now, workout: WorkoutLog? = nil, template: TrainingTemplate? = nil) {
        self.date = date
        self.workout = workout
        let sourceType = workout?.type ?? template?.workoutType ?? .running
        let sourceDuration = workout?.durationMinutes ?? template?.durationMinutes ?? 30
        let sourceIntensity = workout?.workoutIntensity ?? template?.intensity ?? .moderate
        _workoutType = State(initialValue: sourceType)
        _durationMinutes = State(initialValue: sourceDuration)
        _intensity = State(initialValue: sourceIntensity)
        _calories = State(initialValue: workout.map { String(Int($0.caloriesBurned.rounded())) } ?? "")
        _distance = State(initialValue: workout.map { String(format: "%.1f", $0.distanceKm) } ?? "")
        _note = State(initialValue: workout?.note ?? template?.note ?? "")
        _customName = State(initialValue: workout?.name ?? template?.name ?? "")
        _exerciseDetails = State(initialValue: workout?.exerciseDetails ?? template?.exerciseDetails ?? "")
        _sessionDate = State(initialValue: workout?.date ?? date)
    }

    private var estimatedCalories: Int {
        Int(workoutType.kcalPerMinute * durationMinutes * intensity.multiplier)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Training Type") {
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
                    TextField("Session name", text: $customName)
                    DatePicker("Date & Time", selection: $sessionDate)
                    VStack(alignment: .leading) {
                        Text("Duration: \(durationMinutes.formatted(.number.precision(.fractionLength(0...1)))) min")
                        Slider(value: $durationMinutes, in: 5...240, step: 0.5)
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

                Section("Strength, Cardio & Session Plan") {
                    TextField(
                        "Exercises, sets, reps, intervals, or route details",
                        text: $exerciseDetails,
                        axis: .vertical
                    )
                    .lineLimit(4...10)
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
            .navigationTitle(workout == nil ? "Log Training" : "Edit Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        let kcal = Double(calories).map { $0 } ?? Double(estimatedCalories)
        if let workout {
            workout.name = customName.isEmpty ? workoutType.displayName : customName
            workout.workoutType = workoutType.rawValue
            workout.durationMinutes = durationMinutes
            workout.caloriesBurned = kcal
            workout.distanceKm = units.formatter.parseDistanceInput(Double(distance) ?? 0)
            workout.intensity = intensity.rawValue
            workout.exerciseDetails = exerciseDetails.trimmed
            workout.note = note.trimmed.isEmpty ? nil : note.trimmed
            workout.date = sessionDate
        } else {
            let newWorkout = WorkoutLog(
                name: customName.isEmpty ? workoutType.displayName : customName,
                workoutType: workoutType,
                durationMinutes: durationMinutes,
                caloriesBurned: kcal,
                distanceKm: units.formatter.parseDistanceInput(Double(distance) ?? 0),
                intensity: intensity,
                exerciseDetails: exerciseDetails.trimmed,
                note: note.trimmed.isEmpty ? nil : note.trimmed,
                date: sessionDate
            )
            modelContext.insert(newWorkout)
        }
        try? modelContext.save()
        AchievementService.evaluateAll(modelContext: modelContext)
        PeakHaptics.success()
        dismiss()
    }
}
