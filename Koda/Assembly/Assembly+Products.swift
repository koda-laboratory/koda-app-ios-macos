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
