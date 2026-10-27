import Foundation

/// Video links of a recipe (local-first: GRDB + outbox).
protocol RecipeLinkRepository: Sendable {
    /// The live links of a recipe ordered by position.
    func observeLinks(recipeID: UUID) -> AsyncStream<[RecipeLink]>
    /// Adds `url` at the end of the recipe's links.
    @discardableResult
    func addLink(recipeID: UUID, url: URL) async throws(KodaError) -> RecipeLink
    /// Tombstones the link.
    func removeLink(id: UUID) async throws(KodaError)
}
