import AppIntents
import CoreSpotlight
import Foundation

/// A recipe for Siri, Shortcuts and Spotlight. `id` is the row UUID, stable across devices.
struct RecipeEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "intent.recipe.type")
    static let defaultQuery = RecipeEntityQuery()

    let id: UUID
    @Property(title: "intent.recipe.name")
    var name: String
    let minutes: Int?

    init(recipe: Recipe) {
        id = recipe.id
        minutes = recipe.displayMinutes
        name = recipe.name
    }

    var displayRepresentation: DisplayRepresentation {
        if let minutes {
            return DisplayRepresentation(title: "\(name)", subtitle: "intent.recipe.minutes \(minutes)")
        }
        return DisplayRepresentation(title: "\(name)")
    }
}

struct RecipeEntityQuery: EntityStringQuery {
    @Dependency var services: IntentServices

    func entities(for identifiers: [RecipeEntity.ID]) async throws -> [RecipeEntity] {
        let wanted = Set(identifiers)
        return await services.recipes().filter { wanted.contains($0.id) }.map(RecipeEntity.init)
    }

    func entities(matching string: String) async throws -> [RecipeEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return await services.recipes()
            .filter { $0.name.localizedStandardContains(query) }
            .map(RecipeEntity.init)
    }

    func suggestedEntities() async throws -> [RecipeEntity] {
        await services.recipes()
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map(RecipeEntity.init)
    }
}
