import SwiftUI

/// Password input with a trailing eye button that shows or hides the text. Focus is driven by the caller's
/// `FocusState`, which stays on the field when the visibility toggles.
struct PasswordField<Field: Hashable>: View {
    let placeholderKey: LocalizedStringKey
    @Binding var text: String
    var focus: FocusState<Field?>.Binding
    let field: Field
    var onSubmit: () -> Void = {}

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: KodaSpacing.xs) {
            Group {
                if isRevealed {
                    TextField(placeholderKey, text: $text)
                } else {
                    SecureField(placeholderKey, text: $text)
                }
            }
            .platformPasswordField()
            .autocorrectionDisabled()
            .focused(focus, equals: field)
            .onSubmit(onSubmit)

            Button {
                isRevealed.toggle()
                focus.wrappedValue = field
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(KodaTypography.body)
                    .foregroundStyle(KodaColor.textSecondary)
                    .frame(width: KodaSize.hitTarget, height: KodaSize.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? Text("password.hide") : Text("password.show"))
            .accessibilityIdentifier("password-visibility")
        }
    }
}

// MARK: - Previews

#if DEBUG
    private struct PasswordFieldPreview: View {
        @State private var text = "koda-password"
        @FocusState private var focus: Int?

        var body: some View {
            PasswordField(placeholderKey: "login.password.placeholder", text: $text, focus: $focus, field: 0)
                .padding(.horizontal, KodaSpacing.m)
                .frame(minHeight: KodaSize.fieldHeight)
                .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaSpacing.m, style: .continuous))
                .padding()
        }
    }

    #Preview("Password field") {
        PasswordFieldPreview()
            .kodaPreview()
    }

    #Preview("Password field · dark") {
        PasswordFieldPreview()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Password field · Mac", traits: .fixedLayout(width: 500, height: 200)) {
        PasswordFieldPreview()
            .kodaPreview()
    }
#endif
