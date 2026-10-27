import Foundation
import Swinject

extension Assembly {
    final class Products: Swinject.Assembly {
        func assemble(container: Container) {
            container.register(ProductRepository.self) { resolver in
                ProductRepositoryImpl(
                    database: resolver.required(AppDatabase.self),
                    writer: resolver.required(LocalMutationWriter.self)
                )
            }
            .inObjectScope(.container)

            container.register(ProductPhotoRepository.self) { resolver in
                ProductPhotoRepositoryImpl(
                    database: resolver.required(AppDatabase.self),
                    writer: resolver.required(LocalMutationWriter.self),
                    fileDataSource: resolver.required(RecipeImageFileDataSource.self)
                )
            }
            .inObjectScope(.container)

            container.register(ObserveProductDetailUseCase.self) { resolver in
                ObserveProductDetailUseCaseImpl(repository: resolver.required(ProductRepository.self))
            }
            container.register(AddProductPhotoUseCase.self) { resolver in
                AddProductPhotoUseCaseImpl(
                    repository: resolver.required(ProductPhotoRepository.self),
                    transcoder: ImageIOTranscoder()
                )
            }
            container.register(SetProductCoverUseCase.self) { resolver in
                SetProductCoverUseCaseImpl(repository: resolver.required(ProductPhotoRepository.self))
            }
            container.register(DeleteProductPhotoUseCase.self) { resolver in
                DeleteProductPhotoUseCaseImpl(repository: resolver.required(ProductPhotoRepository.self))
            }
            container.register(ObserveProductsUseCase.self) { resolver in
                ObserveProductsUseCaseImpl(repository: resolver.required(ProductRepository.self))
            }
            container.register(ObserveStoresUseCase.self) { resolver in
                ObserveStoresUseCaseImpl(repository: resolver.required(ProductRepository.self))
            }
            container.register(SaveProductUseCase.self) { resolver in
                SaveProductUseCaseImpl(repository: resolver.required(ProductRepository.self))
            }
            container.register(DeleteProductUseCase.self) { resolver in
                DeleteProductUseCaseImpl(repository: resolver.required(ProductRepository.self))
            }
        }
    }
}

// MARK: - ViewModels

extension Assembly {
    static func makeProductsViewModel(container: DependencyContainer = .shared) -> ProductsViewModel {
        ProductsViewModel(
            observeProducts: container.required(ObserveProductsUseCase.self),
            observeStores: container.required(ObserveStoresUseCase.self),
            deleteProduct: container.required(DeleteProductUseCase.self)
        )
    }

    static func makeProductDetailViewModel(
        productID: UUID,
        container: DependencyContainer = .shared
    ) -> ProductDetailViewModel {
        ProductDetailViewModel(
            productID: productID,
            useCases: ProductDetailViewModel.UseCases(
                observeDetail: container.required(ObserveProductDetailUseCase.self),
                addShoppingEntry: container.required(AddShoppingEntryUseCase.self),
                addPhoto: container.required(AddProductPhotoUseCase.self),
                setCover: container.required(SetProductCoverUseCase.self),
                deletePhoto: container.required(DeleteProductPhotoUseCase.self)
            )
        )
    }

    static func makeProductEditorViewModel(
        productID: UUID?,
        container: DependencyContainer = .shared
    ) -> ProductEditorViewModel {
        ProductEditorViewModel(
            productID: productID,
            observeProducts: container.required(ObserveProductsUseCase.self),
            observeStores: container.required(ObserveStoresUseCase.self),
            saveProduct: container.required(SaveProductUseCase.self),
            deleteProduct: container.required(DeleteProductUseCase.self)
        )
    }
}
