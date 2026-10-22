import SwiftUI

// MARK: - Keyboard Margin Modifier

/// Adds breathing room between a focused input and the keyboard. When a field gets focus, the system scrolls the
/// enclosing scroll view only until the field touches the keyboard; it honours the scroll view's bottom safe-area
/// padding, so extra padding here leaves that gap above the keyboard (and at the end of the content otherwise).
/// Apply it to the `ScrollView` of every form.
struct KeyboardMargin: ViewModifier {
    var margin: CGFloat = KodaSpacing.xl

    func body(content: Content) -> some View {
        content.safeAreaPadding(.bottom, margin)
    }
}

// MARK: - View

extension View {
    func keyboardMargin(_ margin: CGFloat = KodaSpacing.xl) -> some View {
        modifier(KeyboardMargin(margin: margin))
    }
}

// MARK: - Previews

#if DEBUG
    private struct KeyboardMarginPreview: View {
        @State private var values = Array(repeating: "", count: 8)

        var body: some View {
            ScrollView {
                VStack(spacing: KodaSpacing.l) {
                    ForEach(values.indices, id: \.self) { index in
                        TextField(text: $values[index]) { Text(verbatim: "Field \(index + 1)") }
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
            }
            .keyboardMargin()
            .dismissKeyboard()
        }
    }

    #Preview("Keyboard margin") {
        KeyboardMarginPreview()
            .kodaPreview()
    }
#endif
