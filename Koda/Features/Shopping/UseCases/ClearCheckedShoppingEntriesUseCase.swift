import Foundation

/// "Vaciar comprados".
protocol ClearCheckedShoppingEntriesUseCase: Sendable {
    @discardableResult
    func execute() async throws(KodaError) -> Int
}

final class ClearCheckedShoppingEntriesUseCaseImpl: ClearCheckedShoppingEntriesUseCase, Sendable {
    private let repository: any ShoppingRepository

    init(repository: any ShoppingRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute() async throws(KodaError) -> Int {
        try await repository.removeCheckedEntries()
    }
}
