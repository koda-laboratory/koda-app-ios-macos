import Foundation

/// Unresolved frozen products with the meal they are for (Shopping "En el congelador", Today "Descongelar hoy").
protocol ObserveFrozenItemsUseCase: Sendable {
    func execute() -> AsyncStream<[FrozenItem]>
}

final class ObserveFrozenItemsUseCaseImpl: ObserveFrozenItemsUseCase, Sendable {
    private let repository: any ShoppingRepository

    init(repository: any ShoppingRepository) {
        self.repository = repository
    }

    func execute() -> AsyncStream<[FrozenItem]> {
        repository.observeFrozenItems()
    }
}

/// "Hecho" on the defrost card: sets `resolved_at`, the only field the app writes on `frozen_items`.
protocol ResolveFrozenItemUseCase: Sendable {
    func execute(frozenItemID: UUID) async throws(KodaError)
}

final class ResolveFrozenItemUseCaseImpl: ResolveFrozenItemUseCase, Sendable {
    private let repository: any ShoppingRepository
    private let clock: @Sendable () -> Date

    init(repository: any ShoppingRepository, clock: @escaping @Sendable () -> Date = { .now }) {
        self.repository = repository
        self.clock = clock
    }

    func execute(frozenItemID: UUID) async throws(KodaError) {
        try await repository.resolveFrozenItem(id: frozenItemID, at: clock())
    }
}
