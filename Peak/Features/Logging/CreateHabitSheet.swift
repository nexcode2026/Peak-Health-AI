import SwiftData
import SwiftUI

struct CreateHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedIcon = "checkmark.circle"
    @State private var selectedColor = "4ECDC4"

    private let icons = [
        "checkmark.circle", "figure.flexibility", "brain.head.profile", "book.fill",
        "moon.zzz.fill", "fork.knife", "figure.walk", "pills.fill", "drop.fill",
        "sun.max.fill", "heart.fill", "leaf.fill", "dumbbell.fill", "bed.double.fill"
    ]
    private let colors = ["4ECDC4", "6C5CE7", "FF6B6B", "F5A623", "00B894", "45B7D1", "FD79A8", "A29BFE"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit Name") {
                    TextField("e.g. Morning Stretch", text: $name)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                PeakHaptics.selection()
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(selectedIcon == icon ? PeakTheme.teal.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(selectedIcon == icon ? PeakTheme.teal : PeakTheme.textSecondary)
                            }
                        }
                    }
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                                PeakHaptics.selection()
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: selectedColor == hex ? 3 : 0)
                                    )
                                    .shadow(color: selectedColor == hex ? Color(hex: hex).opacity(0.5) : .clear, radius: 4)
                            }
                        }
                    }
                }

                Section("Suggestions") {
                    ForEach(PredefinedHabits.defaults, id: \.name) { preset in
                        Button {
                            name = preset.name
                            selectedIcon = preset.icon
                            selectedColor = preset.color
                        } label: {
                            HStack {
                                Image(systemName: preset.icon)
                                    .foregroundStyle(Color(hex: preset.color))
                                Text(preset.name)
                                    .foregroundStyle(PeakTheme.textPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmed.isEmpty)
                }
            }
        }
    }

    private func save() {
        let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first
        let count = (try? modelContext.fetch(FetchDescriptor<HabitDefinition>()))?.count ?? 0
        let habit = HabitDefinition(name: name.trimmed, icon: selectedIcon, colorHex: selectedColor, isCustom: true, sortOrder: count)
        habit.owner = profile
        modelContext.insert(habit)
        try? modelContext.save()
        AchievementService.evaluateAll(modelContext: modelContext)
        PeakHaptics.success()
        dismiss()
    }
}