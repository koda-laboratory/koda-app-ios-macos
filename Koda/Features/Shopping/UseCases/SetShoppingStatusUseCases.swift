import Foundation

/// Three-state change of a shopping entry (tap = have, snowflake = frozen).
protocol SetShoppingEntryStatusUseCase: Sendable {
    func execute(entryID: UUID, status: ShoppingItemStatus) async throws(KodaError)
}

final class SetShoppingEntryStatusUseCaseImpl: SetShoppingEntryStatusUseCase, Sendable {
    private let repository: any ShoppingRepository

    init(repository: any ShoppingRepository) {
        self.repository = repository
    }

    func execute(entryID: UUID, status: ShoppingItemStatus) async throws(KodaError) {
        try await repository.setEntryStatus(id: entryID, status: status)
    }
}

/// Three-state change of one product of a recipe entry.
protocol SetShoppingItemStatusUseCase: Sendable {
    func execute(itemID: UUID, status: ShoppingItemStatus) async throws(KodaError)
}

final class SetShoppingItemStatusUseCaseImpl: SetShoppingItemStatusUseCase, Sendable {
    private let repository: any ShoppingRepository

    init(repository: any ShoppingRepository) {
        self.repository = repository
    }

    func execute(itemID: UUID, status: ShoppingItemStatus) async throws(KodaError) {
        try await repository.setItemStatus(id: itemID, status: status)
    }
}
