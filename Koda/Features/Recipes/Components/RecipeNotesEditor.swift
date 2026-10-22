import SwiftUI

/// "Notas": an auto-growing multiline field with no save button. Saves on focus loss and 1 s after typing.
struct RecipeNotesEditor: View {
    let text: String
    let state: RecipeNotesState
    let onChange: (String) -> Void
    let onFocusChange: (Bool) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s - 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("recipe.notes.title")
                    .font(KodaTypography.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(statusKey)
                    .font(KodaTypography.footnote.weight(.semibold))
                    .foregroundStyle(state == .saved ? KodaColor.brandText : KodaColor.textTertiary)
                    .contentTransition(.opacity)
                    .accessibilityIdentifier("recipe-notes-status")
            }
            TextField(
                "recipe.notes.placeholder",
                text: Binding(get: { text }, set: { onChange($0) }),
                axis: .vertical
            )
            .lineLimit(2...)
            .font(KodaTypography.body)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(.horizontal, KodaSpacing.m)
            .padding(.vertical, KodaSpacing.s + 2)
            .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous)
                    .strokeBorder(isFocused ? KodaColor.brand.opacity(0.5) : KodaColor.brand.opacity(0.12))
            }
            .accessibilityLabel(Text("recipe.notes.accessibility"))
            .accessibilityIdentifier("recipe-notes")
            .onChange(of: isFocused) { onFocusChange(isFocused) }
        }
    }

    private var statusKey: LocalizedStringKey {
        switch state {
        case .saved: "recipe.notes.saved"
        case .editing: "recipe.notes.editing"
        case .saving: "recipe.notes.saving"
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Notes") {
        @Previewable @State var text = "Con caldo de cocido casero queda mucho mejor que con agua."
        RecipeNotesEditor(text: text, state: .saved, onChange: { text = $0 }, onFocusChange: { _ in })
            .padding()
            .kodaPreview()
    }

    #Preview("Notes · dark") {
        RecipeNotesEditor(text: "", state: .editing, onChange: { _ in }, onFocusChange: { _ in })
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Notes · Mac", traits: .fixedLayout(width: 700, height: 300)) {
        RecipeNotesEditor(text: "Notas largas…", state: .saving, onChange: { _ in }, onFocusChange: { _ in })
            .frame(width: 520)
            .kodaPreview()
    }
#endif
