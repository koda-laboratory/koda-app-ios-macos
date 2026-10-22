import Foundation
import Observation

enum ProductsState: Sendable, Equatable {
    case loading
    case ready
}

enum ProductsSheet: Sendable, Equatable, Identifiable {
    case newProduct

    var id: String { "new-product" }
}

enum ProductsIntent: Sendable {
    case appeared
    case newProduct
    case delete(Product)
    case dismissSheet
}

/// The product catalog grouped by category, searchable.
@MainActor
@Observable
final class ProductsViewModel: MVIViewModel {
    // MARK: - Properties

    private(set) var state = ProductsState.loading
    private(set) var products: [Product] = []
    private(set) var stores: [Store] = []
    var searchText = ""
    var presentedSheet: ProductsSheet?
    var toast: Toast?

    @ObservationIgnored private let observeProducts: any ObserveProductsUseCase
    @ObservationIgnored private let observeStores: any ObserveStoresUseCase
    @ObservationIgnored private let deleteProduct: any DeleteProductUseCase
    @ObservationIgnored private var observations: [Task<Void, Never>]?

    // MARK: - Lifecycle

    init(
        observeProducts: any ObserveProductsUseCase,
        observeStores: any ObserveStoresUseCase,
        deleteProduct: any DeleteProductUseCase
    ) {
        self.observeProducts = observeProducts
        self.observeStores = observeStores
        self.deleteProduct = deleteProduct
    }

    deinit {
        observations?.forEach { $0.cancel() }
    }

    // MARK: - Derived

    /// Matching products grouped by category, in category order.
    var sections: [(category: ProductCategory, products: [Product])] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let matching = query.isEmpty ? products : products.filter { $0.name.localizedStandardContains(query) }
        let grouped = Dictionary(grouping: matching, by: \.category)
        return ProductCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    func storeNames(for product: Product) -> [String] {
        stores.filter { product.storeIDs.contains($0.id) }.map(\.name)
    }

    // MARK: - Intents

    func send(_ intent: ProductsIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        case .newProduct:
            presentedSheet = .newProduct
        case .delete(let product):
            do {
                try await deleteProduct.execute(id: product.id)
            } catch {
                toast = .error(error)
            }
        case .dismissSheet:
            presentedSheet = nil
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observations == nil else { return }
        let products = observeProducts.execute()
        let stores = observeStores.execute()
        observations = [
            Task { [weak self] in
                for await items in products {
                    self?.products = items
                    self?.state = .ready
                }
            },
            Task { [weak self] in
                for await items in stores { self?.stores = items }
            },
        ]
    }
}
