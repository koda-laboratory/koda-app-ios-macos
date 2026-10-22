import Foundation

protocol DeleteProductUseCase: Sendable {
    func execute(id: UUID) async throws(KodaError)
}

final class DeleteProductUseCaseImpl: DeleteProductUseCase, Sendable {
    private let repository: any ProductRepository

    init(repository: any ProductRepository) {
        self.repository = repository
    }

    func execute(id: UUID) async throws(KodaError) {
        try await repository.deleteProduct(id: id)
    }
}
