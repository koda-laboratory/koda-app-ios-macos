import Foundation

/// Recipes with their ingredients and sub-recipes (local-first: GRDB + outbox).
protocol RecipeRepository: Sendable {
    func observeRecipes() -> AsyncStream<[Recipe]>
    func observeRecipeDetail(id: UUID) -> AsyncStream<RecipeDetail?>
    /// Every live recipe, ingredient and component, for local expansion and cycle checks.
    func recipeGraph() async throws(KodaError) -> RecipeGraph
    @discardableResult
    func saveRecipe(_ input: RecipeInput) async throws(KodaError) -> Recipe
    func setFavorite(recipeID: UUID, isFavorite: Bool) async throws(KodaError)
    func deleteRecipe(id: UUID) async throws(KodaError)
    @discardableResult
    func addIngredient(_ input: RecipeIngredientInput) async throws(KodaError) -> UUID
    func removeIngredient(id: UUID) async throws(KodaError)
    @discardableResult
    func addComponent(parentID: UUID, childID: UUID, servingsFactor: Double) async throws(KodaError) -> UUID
    func removeComponent(id: UUID) async throws(KodaError)
}
