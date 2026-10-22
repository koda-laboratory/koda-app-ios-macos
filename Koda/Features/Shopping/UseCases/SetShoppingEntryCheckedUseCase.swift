import Foundation

protocol SetShoppingEntryCheckedUseCase: Sendable {
    func execute(entryID: UUID, isChecked: Bool) async throws(KodaError)
}

final class SetShoppingEntryCheckedUseCaseImpl: SetShoppingEntryCheckedUseCase, Sendable {
    private let repository: any ShoppingRepository

    init(repository: any ShoppingRepository) {
        self.repository = repository
    }

    func execute(entryID: UUID, isChecked: Bool) async throws(KodaError) {
        try await repository.setEntryChecked(id: entryID, isChecked: isChecked)
    }
}
