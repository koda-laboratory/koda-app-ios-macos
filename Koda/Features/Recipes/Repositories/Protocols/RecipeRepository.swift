import Foundation

/// Recipes with their ingredients and sub-recipes (local-first: GRDB + outbox).
protocol RecipeRepository: Sendable {
    func observeRecipes() -> AsyncStream<[Recipe]>
    func observeRecipeDetail(id: UUID) -> AsyncStream<RecipeDetail?>
    /// Every live recipe with its ingredient names and consumption stats.
    func observeCatalog() -> AsyncStream<[RecipeCatalogItem]>
    func observeStats(recipeID: UUID) -> AsyncStream<RecipeStats>
    /// Every live recipe, ingredient and component, for local expansion and cycle checks.
    func recipeGraph() async throws(KodaError) -> RecipeGraph
    @discardableResult
    func saveRecipe(_ input: RecipeInput) async throws(KodaError) -> Recipe
    func setFavorite(recipeID: UUID, isFavorite: Bool) async throws(KodaError)
    /// Autosaved notes (`nil` clears them).
    func updateNotes(recipeID: UUID, notes: String?) async throws(KodaError)
    /// Replaces the ingredients and sub-recipes of a recipe in one transaction: rows not in the lists are
    /// tombstoned, changed rows updated, new rows inserted, positions follow the list order.
    func replaceContents(
        recipeID: UUID,
        ingredients: [RecipeIngredientDraft],
        components: [RecipeComponentDraft]
    ) async throws(KodaError)
    func deleteRecipe(id: UUID) async throws(KodaError)
    @discardableResult
    func addIngredient(_ input: RecipeIngredientInput) async throws(KodaError) -> UUID
    func removeIngredient(id: UUID) async throws(KodaError)
    @discardableResult
    func addComponent(parentID: UUID, childID: UUID, servingsFactor: Double) async throws(KodaError) -> UUID
    func removeComponent(id: UUID) async throws(KodaError)
}
