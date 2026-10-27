import SwiftUI

/// Recipes previews over the seeded in-memory database.
@MainActor
enum RecipesPreviewFactory {
    static func makeRecipesView(container: DependencyContainer = PreviewContainer.populated) -> some View {
        AppTabNavigationStack(tab: .recipes) {
            RecipesView(viewModel: Assembly.makeRecipesViewModel(container: container), container: container)
        }
        .environment(AppRouter(selectedTab: .recipes))
    }

    static func makeRecipeDetailView(
        recipeID: UUID = PreviewDatabase.uuid(204),
        container: DependencyContainer = PreviewContainer.populated
    ) -> some View {
        NavigationStack {
            RecipeDetailView(
                viewModel: Assembly.makeRecipeDetailViewModel(recipeID: recipeID, container: container),
                container: container
            )
        }
        .environment(AppRouter(selectedTab: .recipes))
    }

    static func makeRecipeEditorViewModel(
        recipeID: UUID? = PreviewDatabase.uuid(204),
        container: DependencyContainer = PreviewContainer.populated
    ) -> RecipeEditorViewModel {
        Assembly.makeRecipeEditorViewModel(recipeID: recipeID, container: container)
    }

    static let recipe = Recipe(
        id: PreviewDatabase.uuid(204),
        name: "Arroz a la cubana",
        mealTypes: [.lunch],
        nutrients: [.carbs, .protein],
        timeMinutes: 45,
        servings: 2,
        steps: ["Poner el agua a hervir.", "Hacer los huevos."],
        notes: nil,
        imagePath: nil,
        imageSource: nil,
        emoji: nil,
        isFavorite: true
    )

    static let recipeWithCover = Recipe(
        id: PreviewDatabase.uuid(205),
        name: "Tortilla de patata",
        mealTypes: [.dinner],
        nutrients: [.protein],
        timeMinutes: 45,
        servings: 2,
        steps: [],
        notes: nil,
        imagePath: "preview/tortilla/cover.jpg",
        imageSource: .photo,
        emoji: nil,
        isFavorite: false
    )

    static let gallery = [
        RecipeGalleryItem(path: "preview/tortilla/cover.jpg", photoID: PreviewDatabase.uuid(301), isCover: true),
        RecipeGalleryItem(path: "preview/tortilla/2.jpg", photoID: PreviewDatabase.uuid(302), isCover: false),
        RecipeGalleryItem(path: "preview/tortilla/3.jpg", photoID: PreviewDatabase.uuid(303), isCover: false),
    ]

    static let links = [
        "https://www.tiktok.com/@cocinaconana/video/7301234567890",
        "https://www.instagram.com/recetasdelaabuela/reel/C1a2B3c4D5e/",
        "https://youtube.com/shorts/aBcD1234xyz",
        "https://www.directoalpaladar.com/recetas-de-arroces/arroz-a-la-cubana",
    ]
    .enumerated()
    .compactMap { position, string in
        URL(string: string).map {
            RecipeLink(id: PreviewDatabase.uuid(1400 + position), recipeID: recipe.id, url: $0, position: position)
        }
    }

    static func makeAddRecipeLinkViewModel(
        text: String = "",
        container: DependencyContainer = PreviewContainer.populated
    ) -> AddRecipeLinkViewModel {
        let viewModel = Assembly.makeAddRecipeLinkViewModel(recipeID: recipe.id, container: container)
        viewModel.text = text
        return viewModel
    }
}
