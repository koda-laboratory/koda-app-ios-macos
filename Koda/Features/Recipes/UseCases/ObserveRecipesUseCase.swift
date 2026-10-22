import Foundation

/// Every live recipe, by name.
protocol ObserveRecipesUseCase: Sendable {
    func execute() -> AsyncStream<[Recipe]>
}

final class ObserveRecipesUseCaseImpl: ObserveRecipesUseCase, Sendable {
    private let repository: any RecipeRepository

    init(repository: any RecipeRepository) {
        self.repository = repository
    }

    func execute() -> AsyncStream<[Recipe]> {
        repository.observeRecipes()
    }
}
