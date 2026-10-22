import Foundation

/// The shopping list grouped by product category, recipes and free text; pending entries first.
protocol ObserveShoppingListUseCase: Sendable {
    func execute() -> AsyncStream<ShoppingList>
}

final class ObserveShoppingListUseCaseImpl: ObserveShoppingListUseCase, Sendable {
    private let repository: any ShoppingRepository

    init(repository: any ShoppingRepository) {
        self.repository = repository
    }

    func execute() -> AsyncStream<ShoppingList> {
        repository.observeEntries().mapStream(ShoppingList.init(entries:))
    }
}
