import Foundation

/// Expands a recipe and its nested sub-recipes locally (tree + aggregated products).
protocol ExpandRecipeUseCase: Sendable {
    func execute(recipeID: UUID, servings: Double?) async throws(KodaError) -> RecipeExpansion
}

final class ExpandRecipeUseCaseImpl: ExpandRecipeUseCase, Sendable {
    private let repository: any RecipeRepository
    private let expansionService: any RecipeExpansionService

    init(repository: any RecipeRepository, expansionService: any RecipeExpansionService) {
        self.repository = repository
        self.expansionService = expansionService
    }

    func execute(recipeID: UUID, servings: Double?) async throws(KodaError) -> RecipeExpansion {
        let graph = try await repository.recipeGraph()
        return try expansionService.expand(recipeID: recipeID, servings: servings, in: graph)
    }
}
