import Foundation
import Observation

enum ProductEditorState: Sendable, Equatable {
    case loading
    case idle
    case invalidForm
    case saving
    case completed
    case missing

    var isBusy: Bool { self == .loading || self == .saving }
}

enum ProductEditorIntent: Sendable {
    case appeared
    case toggleStore(UUID)
    case save
    case delete
}

/// Creates or edits a product: category, stores, prices and default unit.
@MainActor
@Observable
final class ProductEditorViewModel: FormViewModel {
    // MARK: - Properties

    let productID: UUID?
    private(set) var state: ProductEditorState
    private(set) var stores: [Store] = []
    var form = ProductFormState()
    var toast: Toast?

    @ObservationIgnored private let observeProducts: any ObserveProductsUseCase
    @ObservationIgnored private let observeStores: any ObserveStoresUseCase
    @ObservationIgnored private let saveProduct: any SaveProductUseCase
    @ObservationIgnored private let deleteProduct: any DeleteProductUseCase
    @ObservationIgnored private var storesObservation: Task<Void, Never>?

    // MARK: - Lifecycle

    init(
        productID: UUID?,
        observeProducts: any ObserveProductsUseCase,
        observeStores: any ObserveStoresUseCase,
        saveProduct: any SaveProductUseCase,
        deleteProduct: any DeleteProductUseCase
    ) {
        self.productID = productID
        self.observeProducts = observeProducts
        self.observeStores = observeStores
        self.saveProduct = saveProduct
        self.deleteProduct = deleteProduct
        self.state = productID == nil ? .idle : .loading
    }

    deinit {
        storesObservation?.cancel()
    }

    // MARK: - Derived

    var isEditing: Bool { productID != nil }
    var showsNameError: Bool { state == .invalidForm && form.trimmedName.isEmpty }
    var showsPriceError: Bool { state == .invalidForm && !form.arePricesValid }

    // MARK: - Intents

    func send(_ intent: ProductEditorIntent) async {
        switch intent {
        case .appeared:
            await start()
        case .toggleStore(let id):
            form.storeIDs.formSymmetricDifference([id])
        case .save:
            await save()
        case .delete:
            await delete()
        }
    }

    // MARK: - Private Methods

    private func start() async {
        if storesObservation == nil {
            let stream = observeStores.execute()
            storesObservation = Task { [weak self] in
                for await items in stream { self?.stores = items }
            }
        }
        guard state == .loading, let productID else { return }
        for await products in observeProducts.execute() {
            if let product = products.first(where: { $0.id == productID }) {
                form = ProductFormState(
                    name: product.name,
                    emoji: product.emoji ?? "",
                    category: product.category,
                    storeIDs: product.storeIDs,
                    pricePerKgText: product.pricePerKg.map { $0.formatted(.number.precision(.fractionLength(0...2))) }
                        ?? "",
                    priceTotalText: product.priceTotal.map { $0.formatted(.number.precision(.fractionLength(0...2))) }
                        ?? "",
                    defaultUnit: product.defaultUnit ?? "",
                    notes: product.notes
                )
                state = .idle
            } else {
                state = .missing
            }
            break
        }
    }

    private func save() async {
        guard !state.isBusy else { return }
        guard form.isValid else {
            state = .invalidForm
            return
        }
        state = .saving
        do {
            try await saveProduct.execute(form.input(id: productID))
            state = .completed
        } catch {
            state = .idle
            toast = .error(error)
        }
    }

    private func delete() async {
        guard let productID, !state.isBusy else { return }
        state = .saving
        do {
            try await deleteProduct.execute(id: productID)
            state = .completed
        } catch {
            state = .idle
            toast = .error(error)
        }
    }
}
