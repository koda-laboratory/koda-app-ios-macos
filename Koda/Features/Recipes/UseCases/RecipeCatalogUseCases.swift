import Foundation

/// The recipe catalog with ingredient names and stats (Recipes grid, search, suggestions).
protocol ObserveRecipeCatalogUseCase: Sendable {
    func execute() -> AsyncStream<[RecipeCatalogItem]>
}

final class ObserveRecipeCatalogUseCaseImpl: ObserveRecipeCatalogUseCase, Sendable {
    private let repository: any RecipeRepository

    init(repository: any RecipeRepository) {
        self.repository = repository
    }

    func execute() -> AsyncStream<[RecipeCatalogItem]> {
        repository.observeCatalog()
    }
}

/// Times eaten and last time of one recipe (detail stats).
protocol ObserveRecipeStatsUseCase: Sendable {
    func execute(recipeID: UUID) -> AsyncStream<RecipeStats>
}

final class ObserveRecipeStatsUseCaseImpl: ObserveRecipeStatsUseCase, Sendable {
    private let repository: any RecipeRepository

    init(repository: any RecipeRepository) {
        self.repository = repository
    }

    func execute(recipeID: UUID) -> AsyncStream<RecipeStats> {
        repository.observeStats(recipeID: recipeID)
    }
}

/// Autosaves the notes of a recipe; blank notes are stored as `nil`.
protocol UpdateRecipeNotesUseCase: Sendable {
    func execute(recipeID: UUID, notes: String) async throws(KodaError)
}

final class UpdateRecipeNotesUseCaseImpl: UpdateRecipeNotesUseCase, Sendable {
    private let repository: any RecipeRepository

    init(repository: any RecipeRepository) {
        self.repository = repository
    }

    func execute(recipeID: UUID, notes: String) async throws(KodaError) {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        try await repository.updateNotes(recipeID: recipeID, notes: trimmed.isEmpty ? nil : notes)
    }
}

/// Saves the recipe editor: own fields, ingredients and sub-recipes ("Incluir otra receta"), refusing cycles.
protocol SaveRecipeWithContentsUseCase: Sendable {
    @discardableResult
    func execute(
        _ input: RecipeInput,
        ingredients: [RecipeIngredientDraft],
        components: [RecipeComponentDraft]
    ) async throws(KodaError) -> Recipe
}

final class SaveRecipeWithContentsUseCaseImpl: SaveRecipeWithContentsUseCase, Sendable {
    private let repository: any RecipeRepository
    private let expansionService: any RecipeExpansionService

    init(repository: any RecipeRepository, expansionService: any RecipeExpansionService) {
        self.repository = repository
        self.expansionService = expansionService
    }

    @discardableResult
    func execute(
        _ input: RecipeInput,
        ingredients: [RecipeIngredientDraft],
        components: [RecipeComponentDraft]
    ) async throws(KodaError) -> Recipe {
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw KodaError(type: .badRequest, reason: "A recipe needs a name.") }
        guard input.servings > 0 else { throw KodaError(type: .badRequest, reason: "Servings must be positive.") }
        if ingredients.contains(where: { ($0.quantity ?? 1) <= 0 }) {
            throw KodaError(type: .badRequest, reason: "Quantities must be positive.")
        }
        if components.contains(where: { $0.servingsFactor <= 0 }) {
            throw KodaError(type: .badRequest, reason: "The servings factor must be positive.")
        }
        if let id = input.id {
            let graph = try await repository.recipeGraph()
            for component in components where component.id == nil {
                guard component.childRecipeID != id,
                    !expansionService.wouldCreateCycle(parentID: id, childID: component.childRecipeID, in: graph)
                else {
                    throw KodaError(type: .conflict, reason: "Including this recipe would create a cycle.")
                }
            }
        }

        var normalized = input
        normalized.name = name
        normalized.steps = input.steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let recipe = try await repository.saveRecipe(normalized)
        let validComponents = components.filter { $0.childRecipeID != recipe.id }
        try await repository.replaceContents(recipeID: recipe.id, ingredients: ingredients, components: validComponents)
        return recipe
    }
}
