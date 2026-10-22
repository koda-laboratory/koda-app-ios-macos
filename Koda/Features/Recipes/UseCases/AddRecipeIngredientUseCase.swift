import Foundation

protocol AddRecipeIngredientUseCase: Sendable {
    @discardableResult
    func execute(_ input: RecipeIngredientInput) async throws(KodaError) -> UUID
}

final class AddRecipeIngredientUseCaseImpl: AddRecipeIngredientUseCase, Sendable {
    private let repository: any RecipeRepository

    init(repository: any RecipeRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(_ input: RecipeIngredientInput) async throws(KodaError) -> UUID {
        if let quantity = input.quantity, quantity <= 0 {
            throw KodaError(type: .badRequest, reason: "Quantities must be positive.")
        }
        return try await repository.addIngredient(input)
    }
}
