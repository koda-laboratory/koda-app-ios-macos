import AppIntents
import Foundation

/// A catalog product ("leche") for "Apunta leche en Koda". `id` is the row UUID, stable across devices.
struct ProductEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "intent.product.type")
    static let defaultQuery = ProductEntityQuery()

    let id: UUID
    @Property(title: "intent.product.name")
    var name: String

    init(product: Product) {
        id = product.id
        name = product.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ProductEntityQuery: EntityStringQuery {
    @Dependency var services: IntentServices

    func entities(for identifiers: [ProductEntity.ID]) async throws -> [ProductEntity] {
        let wanted = Set(identifiers)
        return await services.products().filter { wanted.contains($0.id) }.map(ProductEntity.init)
    }

    func entities(matching string: String) async throws -> [ProductEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return await services.products()
            .filter { $0.name.localizedStandardContains(query) }
            .map(ProductEntity.init)
    }

    func suggestedEntities() async throws -> [ProductEntity] {
        await services.products()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map(ProductEntity.init)
    }
}
