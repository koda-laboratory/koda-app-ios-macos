import SwiftUI

/// Detail header: signature gradient with the arcs, the recipe name and its tags.
struct RecipeHero: View {
    let recipe: Recipe

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            KodaGradient.signature
            KodaArcs(colors: [KodaColor.walnutDeep, KodaColor.walnut, KodaColor.taupe], aspectRatio: 300.0 / 260.0)
                .frame(width: 260)
                .opacity(0.55)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 40)
            VStack(alignment: .leading, spacing: KodaSpacing.s - 2) {
                Text(verbatim: recipe.name)
                    .font(KodaTypography.display)
                    .foregroundStyle(KodaColor.cream)
                    .accessibilityAddTraits(.isHeader)
                FlowTags(tags: tags)
            }
            .padding(.horizontal, KodaSpacing.l - 4)
            .padding(.bottom, KodaSpacing.l + 2)
        }
        .frame(height: 330)
        .clipped()
    }

    private var tags: [String] {
        var tags = recipe.mealTypes.map { String(localized: $0.titleResource) }
        if let minutes = recipe.timeMinutes {
            tags.append(String(localized: "recipe.minutes \(minutes)"))
        }
        tags += recipe.nutrients.map { String(localized: $0.titleResource) }
        return tags
    }
}

/// Wrapping row of tags on the hero.
private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: KodaSpacing.xs - 2) {
                ForEach(tags, id: \.self) { TagView(text: $0, onDark: true) }
            }
            VStack(alignment: .leading, spacing: KodaSpacing.xs - 2) {
                HStack(spacing: KodaSpacing.xs - 2) {
                    ForEach(tags.prefix(3), id: \.self) { TagView(text: $0, onDark: true) }
                }
                HStack(spacing: KodaSpacing.xs - 2) {
                    ForEach(tags.dropFirst(3), id: \.self) { TagView(text: $0, onDark: true) }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Recipe hero") {
        RecipeHero(recipe: RecipesPreviewFactory.recipe)
            .kodaPreview()
    }

    #Preview("Recipe hero · dark") {
        RecipeHero(recipe: RecipesPreviewFactory.recipe)
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Recipe hero · Mac", traits: .fixedLayout(width: 900, height: 400)) {
        RecipeHero(recipe: RecipesPreviewFactory.recipe)
            .kodaPreview()
    }
#endif
