import SwiftUI

/// Detail header. With a cover: the photo full-bleed under a scrim, the name and its tags. Without one: the signature
/// gradient with the arcs and "Añadir portada" (approved mockups `Main` and `NoCover`).
struct RecipeHero: View {
    let recipe: Recipe
    var onAddCover: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if recipe.imagePath != nil {
                RecipeImageView(path: recipe.imagePath, maxPixelSize: 1600) { arcsBackground }
                KodaGradient.photoScrim
            } else {
                arcsBackground
            }
            VStack(alignment: .leading, spacing: KodaSpacing.s - 2) {
                Text(verbatim: recipe.name)
                    .font(KodaTypography.display)
                    .foregroundStyle(KodaColor.cream)
                    .accessibilityAddTraits(.isHeader)
                FlowTags(tags: tags)
                if recipe.imagePath == nil, let onAddCover {
                    AddCoverButton(action: onAddCover)
                        .padding(.top, KodaSpacing.xxs)
                }
            }
            .padding(.horizontal, KodaSpacing.l - 4)
            .padding(.bottom, KodaSpacing.l + 2)
        }
        .frame(height: KodaSize.recipeHeroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var arcsBackground: some View {
        ZStack {
            KodaGradient.signature
            KodaArcs(colors: [KodaColor.walnutDeep, KodaColor.walnut, KodaColor.taupe], aspectRatio: 300.0 / 260.0)
                .frame(width: 260)
                .opacity(0.55)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 40)
        }
    }

    private var tags: [String] {
        var tags = recipe.mealTypes.map { String(localized: $0.titleResource) }
        if let minutes = recipe.displayMinutes {
            tags.append(String(localized: "recipe.minutes \(minutes)"))
        }
        tags += recipe.nutrients.map { String(localized: $0.titleResource) }
        return tags
    }
}

/// "Añadir portada": a translucent pill on the dark hero.
private struct AddCoverButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("recipe.photos.add-cover", systemImage: "camera")
                .font(KodaTypography.subheadline.weight(.bold))
                .foregroundStyle(KodaColor.cream)
                .padding(.horizontal, KodaSpacing.m)
                .frame(minHeight: KodaSize.hitTarget)
                .background(KodaColor.onyx.opacity(0.35), in: Capsule())
                .overlay(Capsule().strokeBorder(KodaColor.taupe.opacity(0.5)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recipe-add-cover")
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
    #Preview("Recipe hero · no cover") {
        RecipeHero(recipe: RecipesPreviewFactory.recipe, onAddCover: {})
            .kodaPreview()
    }

    #Preview("Recipe hero · cover loading") {
        RecipeHero(recipe: RecipesPreviewFactory.recipeWithCover)
            .kodaPreview()
    }

    #Preview("Recipe hero · dark") {
        RecipeHero(recipe: RecipesPreviewFactory.recipe, onAddCover: {})
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Recipe hero · Mac", traits: .fixedLayout(width: 900, height: 400)) {
        RecipeHero(recipe: RecipesPreviewFactory.recipe, onAddCover: {})
            .kodaPreview()
    }
#endif
