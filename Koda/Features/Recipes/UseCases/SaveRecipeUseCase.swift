import Foundation

/// Creates or updates a recipe's own fields.
protocol SaveRecipeUseCase: Sendable {
    @discardableResult
    func execute(_ input: RecipeInput) async throws(KodaError) -> Recipe
}

final class SaveRecipeUseCaseImpl: SaveRecipeUseCase, Sendable {
    private let repository: any RecipeRepository

    init(repository: any RecipeRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(_ input: RecipeInput) async throws(KodaError) -> Recipe {
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw KodaError(type: .badRequest, reason: "A recipe needs a name.") }
        guard input.servings > 0 else { throw KodaError(type: .badRequest, reason: "Servings must be positive.") }
        var normalized = input
        normalized.name = name
        normalized.steps = input.steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return try await repository.saveRecipe(normalized)
    }
}
