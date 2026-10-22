import SwiftUI

// MARK: - Chip

/// Selectable filter chip: onyx when selected, surface with a hairline otherwise.
struct ChipView: View {
    let titleKey: LocalizedStringKey
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titleKey)
                .font(KodaTypography.subheadline.weight(isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? KodaColor.onInverse : KodaColor.textPrimary)
                .padding(.horizontal, KodaSpacing.s + 2)
                .frame(minHeight: KodaSize.chipHeight)
                .background(isSelected ? KodaColor.inverse : KodaColor.surface, in: Capsule())
                .overlay {
                    if !isSelected {
                        Capsule().strokeBorder(KodaColor.brand.opacity(0.2))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Read-only tag ("Comemos fuera", "45 min").
struct TagView: View {
    let text: String
    var onDark = false

    var body: some View {
        Text(verbatim: text)
            .font(KodaTypography.footnote.weight(.semibold))
            .foregroundStyle(onDark ? KodaColor.cream : KodaColor.brandText)
            .padding(.horizontal, KodaSpacing.s - 2)
            .padding(.vertical, KodaSpacing.xxs + 1)
            .background(onDark ? KodaColor.taupe.opacity(0.25) : KodaColor.chip, in: Capsule())
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Chips") {
        HStack {
            ChipView(titleKey: "recipes.filter.all", isSelected: true) {}
            ChipView(titleKey: "recipes.filter.quick") {}
            TagView(text: "Comemos fuera")
        }
        .padding()
        .kodaPreview()
    }

    #Preview("Chips · dark") {
        HStack {
            ChipView(titleKey: "recipes.filter.all", isSelected: true) {}
            ChipView(titleKey: "recipes.filter.favorites") {}
        }
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Chips · Mac", traits: .fixedLayout(width: 600, height: 200)) {
        ChipView(titleKey: "recipes.filter.all", isSelected: true) {}
            .kodaPreview()
    }
#endif
