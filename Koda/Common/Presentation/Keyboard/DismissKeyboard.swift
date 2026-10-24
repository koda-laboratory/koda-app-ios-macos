import SwiftUI

// MARK: - Dismiss Keyboard Modifier

/// Resigns the first responder when the user taps outside a text input. A no-op on the Mac.
///
/// Not an `onTapGesture`: on a `Form` it would swallow the taps of buttons, toggles and menus in its rows.
struct DismissKeyboard: ViewModifier {
    func body(content: Content) -> some View {
        content.platformKeyboardDismissTap()
    }
}

// MARK: - View

extension View {
    func dismissKeyboard() -> some View {
        modifier(DismissKeyboard())
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Dismiss keyboard") {
        VStack(spacing: KodaSpacing.m) {
            TextField(text: .constant("")) { Text(verbatim: "Tap outside to dismiss the keyboard") }
                .textFieldStyle(.roundedBorder)
            Text(verbatim: "Tap this area")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .dismissKeyboard()
        .kodaPreview()
    }
#endif
