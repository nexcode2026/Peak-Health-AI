import SwiftUI

/// Enables swipe-down interactive keyboard dismissal on scrollable screens.
struct PeakKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
    }
}

extension View {
    /// Apply on `ScrollView` / `List` so dragging down dismisses the keyboard.
    func peakDismissKeyboardOnSwipe() -> some View {
        modifier(PeakKeyboardDismissModifier())
    }

    /// Tap outside text fields to resign first responder (non-scroll screens).
    func peakDismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}