import SwiftUI

/// Recipe detail header (`DetailHero`). With a cover: the photo full-bleed under a scrim, the name and its tags.
/// Without one: the signature gradient with the arcs and "Añadir portada" (approved mockups `Main` and `NoCover`).
struct RecipeHero: View {
    let recipe: Recipe
    var onAddCover: (() -> Void)?

    var body: some View {
        DetailHero(title: recipe.name, tags: tags, imagePath: recipe.imagePath, onAddCover: onAddCover) {
            DetailHeroArcsBackground()
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
