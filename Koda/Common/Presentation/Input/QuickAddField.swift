import SwiftUI

// MARK: - Quick Add Field

/// "Añadir… leche, pilas, una receta": a single-line field with a plus glyph that submits on Return.
struct QuickAddField: View {
    let placeholderKey: LocalizedStringKey
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: KodaSpacing.s - 2) {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(KodaColor.textTertiary)
                .accessibilityHidden(true)
            TextField(placeholderKey, text: $text)
                .font(KodaTypography.body)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .focused(focus)
                .onSubmit(onSubmit)
                .accessibilityIdentifier("quick-add-field")
        }
        .padding(.horizontal, KodaSpacing.s + 2)
        .frame(minHeight: 50)
        .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaSpacing.m, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KodaSpacing.m, style: .continuous)
                .strokeBorder(KodaColor.brand.opacity(0.12))
        }
    }
}

// MARK: - Previews

#if DEBUG
    private struct QuickAddFieldPreview: View {
        @State private var text = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            QuickAddField(placeholderKey: "shopping.add.placeholder", text: $text, focus: $isFocused) {}
                .padding()
                .dismissKeyboard()
        }
    }

    #Preview("Quick add") {
        QuickAddFieldPreview().kodaPreview()
    }

    #Preview("Quick add · dark") {
        QuickAddFieldPreview().kodaPreview().preferredColorScheme(.dark)
    }

    #Preview("Quick add · Mac", traits: .fixedLayout(width: 600, height: 200)) {
        QuickAddFieldPreview().kodaPreview()
    }
#endif
