import SwiftUI

// MARK: - Stat Pill

/// A number with a caption ("6 · veces comida").
struct StatPill: View {
    let value: String
    let captionKey: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(KodaTypography.title)
                .foregroundStyle(KodaColor.textPrimary)
            Text(captionKey)
                .font(KodaTypography.caption)
                .foregroundStyle(KodaColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KodaSpacing.s)
        .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Stat pills") {
        HStack {
            StatPill(value: "6", captionKey: "recipe.stats.times")
            StatPill(value: "9 d", captionKey: "recipe.stats.since")
            StatPill(value: "2", captionKey: "recipe.stats.servings")
        }
        .padding()
        .kodaPreview()
    }

    #Preview("Stat pills · dark") {
        StatPill(value: "6", captionKey: "recipe.stats.times")
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Stat pills · Mac", traits: .fixedLayout(width: 600, height: 200)) {
        StatPill(value: "6", captionKey: "recipe.stats.times")
            .frame(width: 200)
            .kodaPreview()
    }
#endif
