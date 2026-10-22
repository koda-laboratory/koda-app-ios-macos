import Foundation

protocol DeleteRecipeUseCase: Sendable {
    func execute(recipeID: UUID) async throws(KodaError)
}

final class DeleteRecipeUseCaseImpl: DeleteRecipeUseCase, Sendable {
    private let repository: any RecipeRepository

    init(repository: any RecipeRepository) {
        self.repository = repository
    }

    func execute(recipeID: UUID) async throws(KodaError) {
        try await repository.deleteRecipe(id: recipeID)
    }
}
