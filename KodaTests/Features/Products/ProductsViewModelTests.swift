import Foundation
import Testing

@testable import Koda

@MainActor
@Suite("Products screens")
struct ProductsViewModelTests {
    @Test("The catalog groups by category, searches and deletes")
    func catalog() async throws {
        let environment = try await FeatureEnvironment.make()
        try await environment.product("Leche", category: .basics)
        let bleach = try await environment.product("Lejía", category: .cleaning)
        let viewModel = ProductsViewModel(
            observeProducts: environment.observeProducts,
            observeStores: environment.observeStores,
            deleteProduct: DeleteProductUseCaseImpl(repository: environment.products)
        )
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.products.count == 2 })
        #expect(viewModel.sections.map(\.category) == [.basics, .cleaning])
        viewModel.searchText = "lej"
        #expect(viewModel.sections.map(\.category) == [.cleaning])

        await viewModel.send(.delete(bleach))
        #expect(await eventually { viewModel.products.count == 1 })
        await viewModel.send(.newProduct)
        #expect(viewModel.presentedSheet == .newProduct)
    }

    @Test("The editor validates, creates with stores and prices, and edits an existing product")
    func editor() async throws {
        let environment = try await FeatureEnvironment.make()
        let store = try await environment.products.saveStore(StoreInput(name: "Mercadona"))
        let create = ProductEditorViewModel(
            productID: nil,
            observeProducts: environment.observeProducts,
            observeStores: environment.observeStores,
            saveProduct: SaveProductUseCaseImpl(repository: environment.products),
            deleteProduct: DeleteProductUseCaseImpl(repository: environment.products)
        )
        await create.send(.appeared)
        create.form.pricePerKgText = "abc"
        await create.send(.save)
        #expect(create.state == .invalidForm)
        #expect(create.showsNameError)
        #expect(create.showsPriceError)

        create.form.name = "Carrilleras"
        create.form.pricePerKgText = "12,5"
        create.form.category = .food
        await create.send(.toggleStore(store.id))
        await create.send(.save)
        #expect(create.state == .completed)

        let products = try #require(await firstValue(environment.observeProducts.execute()))
        let product = try #require(products.first)
        #expect(product.pricePerKg == 12.5)
        #expect(product.storeIDs == [store.id])

        let edit = ProductEditorViewModel(
            productID: product.id,
            observeProducts: environment.observeProducts,
            observeStores: environment.observeStores,
            saveProduct: SaveProductUseCaseImpl(repository: environment.products),
            deleteProduct: DeleteProductUseCaseImpl(repository: environment.products)
        )
        await edit.send(.appeared)
        #expect(edit.state == .idle)
        #expect(edit.form.name == "Carrilleras")
        edit.form.defaultUnit = "g"
        await edit.send(.save)
        let updated = try #require(await firstValue(environment.observeProducts.execute()))
        #expect(updated.first?.defaultUnit == "g")
    }
}
