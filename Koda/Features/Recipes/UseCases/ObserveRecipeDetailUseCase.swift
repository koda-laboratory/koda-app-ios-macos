import Foundation

/// A recipe with its ingredients and direct sub-recipes; `nil` once it is deleted.
protocol ObserveRecipeDetailUseCase: Sendable {
    func execute(recipeID: UUID) -> AsyncStream<RecipeDetail?>
}

final class ObserveRecipeDetailUseCaseImpl: ObserveRecipeDetailUseCase, Sendable {
    private let repository: any RecipeRepository

    init(repository: any RecipeRepository) {
        self.repository = repository
    }

    func execute(recipeID: UUID) -> AsyncStream<RecipeDetail?> {
        repository.observeRecipeDetail(id: recipeID)
    }
}
