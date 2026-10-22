import Foundation

protocol SetRecipeFavoriteUseCase: Sendable {
    func execute(recipeID: UUID, isFavorite: Bool) async throws(KodaError)
}

final class SetRecipeFavoriteUseCaseImpl: SetRecipeFavoriteUseCase, Sendable {
    private let repository: any RecipeRepository

    init(repository: any RecipeRepository) {
        self.repository = repository
    }

    func execute(recipeID: UUID, isFavorite: Bool) async throws(KodaError) {
        try await repository.setFavorite(recipeID: recipeID, isFavorite: isFavorite)
    }
}
