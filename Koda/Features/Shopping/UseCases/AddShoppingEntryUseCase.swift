import Foundation

/// Adds a product or a free text ("Añadir…", Siri, the widget control).
protocol AddShoppingEntryUseCase: Sendable {
    @discardableResult
    func execute(_ input: NewShoppingEntry) async throws(KodaError) -> ShoppingEntry
}

final class AddShoppingEntryUseCaseImpl: AddShoppingEntryUseCase, Sendable {
    private let repository: any ShoppingRepository

    init(repository: any ShoppingRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(_ input: NewShoppingEntry) async throws(KodaError) -> ShoppingEntry {
        var normalized = input
        if case .text(let text) = input.item {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw KodaError(type: .badRequest, reason: "A shopping entry needs a text.")
            }
            normalized.item = .text(trimmed)
        }
        if let quantity = input.quantity, quantity <= 0 {
            throw KodaError(type: .badRequest, reason: "Quantities must be positive.")
        }
        return try await repository.addEntry(normalized)
    }
}
