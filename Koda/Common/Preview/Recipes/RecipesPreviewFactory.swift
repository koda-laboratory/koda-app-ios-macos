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
        emoji: nil,
        isFavorite: true
    )
}
