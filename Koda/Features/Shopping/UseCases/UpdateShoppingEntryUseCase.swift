import Foundation

/// Changes the text, quantity or unit of an entry (resolved by `name_updated_at` on the server).
protocol UpdateShoppingEntryUseCase: Sendable {
    func execute(entryID: UUID, text: String?, quantity: Double?, unit: String?) async throws(KodaError)
}

final class UpdateShoppingEntryUseCaseImpl: UpdateShoppingEntryUseCase, Sendable {
    private let repository: any ShoppingRepository

    init(repository: any ShoppingRepository) {
        self.repository = repository
    }

    func execute(entryID: UUID, text: String?, quantity: Double?, unit: String?) async throws(KodaError) {
        if let quantity, quantity <= 0 {
            throw KodaError(type: .badRequest, reason: "Quantities must be positive.")
        }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        try await repository.updateEntry(
            id: entryID,
            text: trimmed?.isEmpty == true ? nil : trimmed,
            quantity: quantity,
            unit: unit
        )
    }
}
