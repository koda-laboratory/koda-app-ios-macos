protocol ObserveStoresUseCase: Sendable {
    func execute() -> AsyncStream<[Store]>
}

final class ObserveStoresUseCaseImpl: ObserveStoresUseCase, Sendable {
    private let repository: any ProductRepository

    init(repository: any ProductRepository) {
        self.repository = repository
    }

    func execute() -> AsyncStream<[Store]> {
        repository.observeStores()
    }
}
