protocol ObserveProductsUseCase: Sendable {
    func execute() -> AsyncStream<[Product]>
}

final class ObserveProductsUseCaseImpl: ObserveProductsUseCase, Sendable {
    private let repository: any ProductRepository

    init(repository: any ProductRepository) {
        self.repository = repository
    }

    func execute() -> AsyncStream<[Product]> {
        repository.observeProducts()
    }
}
