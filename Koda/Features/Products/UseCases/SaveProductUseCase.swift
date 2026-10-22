import Foundation

/// Creates or updates a product locally (synced later).
protocol SaveProductUseCase: Sendable {
    @discardableResult
    func execute(_ input: ProductInput) async throws(KodaError) -> Product
}

final class SaveProductUseCaseImpl: SaveProductUseCase, Sendable {
    private let repository: any ProductRepository

    init(repository: any ProductRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(_ input: ProductInput) async throws(KodaError) -> Product {
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw KodaError(type: .badRequest, reason: "A product needs a name.")
        }
        var normalized = input
        normalized.name = name
        return try await repository.saveProduct(normalized)
    }
}
