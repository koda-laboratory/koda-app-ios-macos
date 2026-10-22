import Foundation

/// Ticks one product of a recipe entry.
protocol SetShoppingItemCheckedUseCase: Sendable {
    func execute(itemID: UUID, isChecked: Bool) async throws(KodaError)
}

final class SetShoppingItemCheckedUseCaseImpl: SetShoppingItemCheckedUseCase, Sendable {
    private let repository: any ShoppingRepository

    init(repository: any ShoppingRepository) {
        self.repository = repository
    }

    func execute(itemID: UUID, isChecked: Bool) async throws(KodaError) {
        try await repository.setItemChecked(id: itemID, isChecked: isChecked)
    }
}
