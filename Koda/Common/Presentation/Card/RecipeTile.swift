import SwiftUI

// MARK: - Recipe Tile

/// Recipe grid tile: the cover photo, or a colour block with the recipe initials when there is none, the name and a
/// detail.
struct RecipeTile: View {
    let recipeID: UUID
    let name: String
    let detail: String
    var imagePath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.xs) {
            RecipeImageView(path: imagePath, maxPixelSize: 500) {
                InitialsBlock(recipeID: recipeID, name: name)
            }
            .frame(maxWidth: .infinity)
            .frame(height: KodaSize.recipeTileHeight)
            .clipShape(RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
            .accessibilityHidden(true)
            Text(verbatim: name)
                .font(KodaTypography.subheadline.weight(.bold))
                .foregroundStyle(KodaColor.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if !detail.isEmpty {
                Text(verbatim: detail)
                    .font(KodaTypography.footnote)
                    .foregroundStyle(KodaColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The recipe initials on its deterministic colour block.
private struct InitialsBlock: View {
    let recipeID: UUID
    let name: String

    var body: some View {
        let palette = RecipeTilePalette(id: recipeID)
        Text(verbatim: RecipeTilePalette.initials(of: name))
            .font(KodaTypography.initials)
            .foregroundStyle(palette.foreground)
            .padding(KodaSpacing.s)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .background(palette.background)
    }
}

/// Deterministic colour block per recipe, from the palette only.
struct RecipeTilePalette {
    let background: Color
    let foreground: Color

    private static let pairs: [(Color, Color)] = [
        (KodaColor.walnut, KodaColor.taupe),
        (KodaColor.taupeLight, KodaColor.walnut),
        (KodaColor.onyx, KodaColor.taupe),
        (KodaColor.taupe, KodaColor.walnutDeep),
        (KodaColor.walnutLight, KodaColor.cream),
        (KodaColor.walnutDeep, KodaColor.taupeLight),
    ]

    init(id: UUID) {
        let index = id.uuidString.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        let pair = Self.pairs[index % Self.pairs.count]
        background = pair.0
        foreground = pair.1
    }

    /// "Arroz a la cubana" → "Ar".
    static func initials(of name: String) -> String {
        let letters = name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2)
        return letters.prefix(1).uppercased() + letters.dropFirst().lowercased()
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Recipe tiles") {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)],
            spacing: KodaSpacing.s
        ) {
            ForEach(PresentationPreviewFactory.recipeNames, id: \.self) { name in
                RecipeTile(recipeID: PresentationPreviewFactory.id(for: name), name: name, detail: "45 min · 6 veces")
            }
        }
        .padding()
        .kodaPreview()
    }

    #Preview("Recipe tiles · dark") {
        RecipeTile(recipeID: UUID(), name: "Gazpacho", detail: "Vegetales")
            .frame(width: 180)
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Recipe tiles · Mac", traits: .fixedLayout(width: 900, height: 400)) {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .top)], spacing: KodaSpacing.s) {
            ForEach(PresentationPreviewFactory.recipeNames, id: \.self) { name in
                RecipeTile(recipeID: PresentationPreviewFactory.id(for: name), name: name, detail: "45 min")
            }
        }
        .padding()
        .kodaPreview()
    }
#endif
