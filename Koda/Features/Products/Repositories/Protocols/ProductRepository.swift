import Foundation

/// Catalog of products and stores (local-first: GRDB + outbox).
protocol ProductRepository: Sendable {
    func observeProducts() -> AsyncStream<[Product]>
    func observeStores() -> AsyncStream<[Store]>
    @discardableResult
    func saveProduct(_ input: ProductInput) async throws(KodaError) -> Product
    func deleteProduct(id: UUID) async throws(KodaError)
    @discardableResult
    func saveStore(_ input: StoreInput) async throws(KodaError) -> Store
    func deleteStore(id: UUID) async throws(KodaError)
}
