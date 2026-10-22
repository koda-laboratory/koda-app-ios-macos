import Foundation

/// "Incluir otra receta": adds a sub-recipe, refusing cycles locally (the backend also rejects them).
protocol AddRecipeComponentUseCase: Sendable {
    @discardableResult
    func execute(parentID: UUID, childID: UUID, servingsFactor: Double) async throws(KodaError) -> UUID
}

final class AddRecipeComponentUseCaseImpl: AddRecipeComponentUseCase, Sendable {
    private let repository: any RecipeRepository
    private let expansionService: any RecipeExpansionService

    init(repository: any RecipeRepository, expansionService: any RecipeExpansionService) {
        self.repository = repository
        self.expansionService = expansionService
    }

    @discardableResult
    func execute(parentID: UUID, childID: UUID, servingsFactor: Double) async throws(KodaError) -> UUID {
        guard servingsFactor > 0 else {
            throw KodaError(type: .badRequest, reason: "The servings factor must be positive.")
        }
        let graph = try await repository.recipeGraph()
        guard expansionService.wouldCreateCycle(parentID: parentID, childID: childID, in: graph) == false else {
            throw KodaError(type: .conflict, reason: "Including this recipe would create a cycle.")
        }
        return try await repository.addComponent(parentID: parentID, childID: childID, servingsFactor: servingsFactor)
    }
}
