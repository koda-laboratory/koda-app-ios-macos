import Foundation

protocol RemoveShoppingEntryUseCase: Sendable {
    func execute(entryID: UUID) async throws(KodaError)
}

final class RemoveShoppingEntryUseCaseImpl: RemoveShoppingEntryUseCase, Sendable {
    private let repository: any ShoppingRepository

    init(repository: any ShoppingRepository) {
        self.repository = repository
    }

    func execute(entryID: UUID) async throws(KodaError) {
        try await repository.removeEntry(id: entryID)
    }
}
