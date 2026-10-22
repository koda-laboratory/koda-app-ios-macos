import Foundation

/// Adds a recipe as ONE entry of kind `recipe` with its flattened products: nested sub-recipes are expanded/// locally (cycle-safe, `servings_factor`, scaled to `servings`) and aggregated by product and unit.
protocol AddRecipeToShoppingListUseCase: Sendable {
    @discardableResult
    func execute(
        recipeID: UUID,
        servings: Double?,
        source: ShoppingEntrySource,
        mealPlanEntryID: UUID?
    ) async throws(KodaError) -> ShoppingEntry
}

final class AddRecipeToShoppingListUseCaseImpl: AddRecipeToShoppingListUseCase, Sendable {
    private let recipeRepository: any RecipeRepository
    private let shoppingRepository: any ShoppingRepository
    private let expansionService: any RecipeExpansionService

    init(
        recipeRepository: any RecipeRepository,
        shoppingRepository: any ShoppingRepository,
        expansionService: any RecipeExpansionService
    ) {
        self.recipeRepository = recipeRepository
        self.shoppingRepository = shoppingRepository
        self.expansionService = expansionService
    }

    @discardableResult
    func execute(
        recipeID: UUID,
        servings: Double?,
        source: ShoppingEntrySource,
        mealPlanEntryID: UUID?
    ) async throws(KodaError) -> ShoppingEntry {
        if let servings, servings <= 0 {
            throw KodaError(type: .badRequest, reason: "Servings must be positive.")
        }
        let graph = try await recipeRepository.recipeGraph()
        let expansion = try expansionService.expand(recipeID: recipeID, servings: servings, in: graph)
        let input = NewRecipeShoppingEntry(
            recipeID: recipeID,
            label: expansion.label,
            servings: servings ?? graph.recipes[recipeID]?.servings,
            items: expansion.items.map { item in
                NewRecipeShoppingEntry.Item(productID: item.productID, quantity: item.quantity, unit: item.unit)
            },
            source: source,
            mealPlanEntryID: mealPlanEntryID
        )
        return try await shoppingRepository.addRecipeEntry(input)
    }
}
