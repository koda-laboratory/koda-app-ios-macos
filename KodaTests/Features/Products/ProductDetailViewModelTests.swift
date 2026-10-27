import Foundation
import Testing

@testable import Koda

@MainActor
@Suite("Product detail and add-video screens")
struct ProductDetailViewModelTests {
    @Test("The detail loads, adds the product to the shopping list and opens the editor and the photo sheet")
    func productDetail() async throws {
        let environment = try await FeatureEnvironment.make()
        let product = try await environment.product("Aguja de ternera")
        let viewModel = makeViewModel(environment, productID: product.id)

        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.state == .loaded })
        #expect(viewModel.detail?.product.name == "Aguja de ternera")

        await viewModel.send(.addToShopping)
        #expect(viewModel.toast?.messageKey == "product.toast.added-to-shopping")
        let entries = try await TestDatabase.count(
            "shopping_entries",
            in: environment.database,
            where: "product_id = '\(product.id.lowercasedString)'"
        )
        #expect(entries == 1)

        await viewModel.send(.addPhotoTapped)
        #expect(viewModel.presentedSheet == .addPhoto(asCover: true))
        await viewModel.send(.edit)
        #expect(viewModel.presentedSheet == .edit)
    }

    @Test("A deleted product shows the missing state")
    func missing() async throws {
        let environment = try await FeatureEnvironment.make()
        let viewModel = makeViewModel(environment, productID: UUID())
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.state == .missing })
    }

    @Test("Add video: pasted text keeps only the link, Añadir is enabled once valid and completes")
    func addLink() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Arroz a la cubana")
        let viewModel = AddRecipeLinkViewModel(recipeID: recipe.id, addLink: environment.addLink)
        #expect(!viewModel.canSubmit)

        viewModel.text = "hola"
        #expect(viewModel.detection == nil)
        await viewModel.send(.pasted("Mira https://www.tiktok.com/@cocinaconana/video/1 😋"))
        #expect(viewModel.text == "https://www.tiktok.com/@cocinaconana/video/1")
        #expect(viewModel.detection?.account == "@cocinaconana")
        #expect(viewModel.canSubmit)

        await viewModel.send(.submit)
        #expect(viewModel.state == .completed)
        #expect(try await TestDatabase.count("recipe_links", in: environment.database) == 1)
    }

    private func makeViewModel(_ environment: FeatureEnvironment, productID: UUID) -> ProductDetailViewModel {
        ProductDetailViewModel(
            productID: productID,
            useCases: ProductDetailViewModel.UseCases(
                observeDetail: environment.observeProductDetail,
                addShoppingEntry: AddShoppingEntryUseCaseImpl(repository: environment.shopping),
                addPhoto: environment.addProductPhoto,
                setCover: environment.setProductCover,
                deletePhoto: environment.deleteProductPhoto
            )
        )
    }
}
