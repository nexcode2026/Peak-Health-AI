import SwiftUI

struct MoodPicker: View {
    @Binding var rating: Int
    var onSelect: ((Int) -> Void)?

    private let moods: [(emoji: String, value: Int)] = [
        ("😔", 1), ("😕", 2), ("😐", 3), ("🙂", 4), ("😄", 5)
    ]

    var body: some View {
        HStack(spacing: PeakTheme.Spacing.md) {
            ForEach(moods, id: \.value) { mood in
                Button {
                    rating = mood.value
                    PeakHaptics.selection()
                    onSelect?(mood.value)
                } label: {
                    Text(mood.emoji)
                        .font(.system(size: rating == mood.value ? 40 : 32))
                        .scaleEffect(rating == mood.value ? 1.1 : 1)
                        .animation(.spring(response: 0.3), value: rating)
                }
                .accessibilityLabel("Mood \(mood.value) of 5")
            }
        }
    }
}