import SwiftData
import SwiftUI

struct LogWaterSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @State private var amountML: Double = 250
    @State private var beverage: BeverageType = .water

    private var formatter: UnitFormatter {
        UnitFormatter(system: UnitSystem(preferredUnits: profiles.first?.preferredUnits ?? "metric"))
    }
    @State private var note = ""
    let date: Date

    init(date: Date = .now) {
        self.date = date
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Beverage") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                        ForEach(BeverageType.allCases) { type in
                            Button {
                                beverage = type
                                amountML = Double(type.defaultML)
                                PeakHaptics.selection()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                    Text(type.displayName)
                                        .font(PeakTheme.Typography.micro)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(beverage == type ? PeakTheme.teal.opacity(0.15) : PeakTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.sm))
                                .foregroundStyle(beverage == type ? PeakTheme.teal : PeakTheme.textSecondary)
                            }
                        }
                    }
                }

                Section("Amount") {
                    Text(formatter.formatWater(Int(amountML)))
                        .font(PeakTheme.Typography.title)
                        .frame(maxWidth: .infinity)
                    Slider(value: $amountML, in: 50...1000, step: 50)
                        .tint(PeakTheme.teal)
                    HStack {
                        ForEach([150, 250, 350, 500], id: \.self) { ml in
                            Button(formatter.formatWaterShort(ml)) { amountML = Double(ml) }
                                .buttonStyle(PeakChipStyle(isSelected: Int(amountML) == ml))
                        }
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $note)
                }
            }
            .scrollContentBackground(.hidden)
            .peakScreenBackground()
            .navigationTitle("Log Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let log = HydrationLog(amountML: Int(amountML), beverageType: beverage, date: date, note: note.isEmpty ? nil : note)
        modelContext.insert(log)
        try? modelContext.save()
        AchievementService.evaluateAll(modelContext: modelContext)
        PeakHaptics.success()
        dismiss()
    }
}
