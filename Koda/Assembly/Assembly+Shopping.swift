import Swinject

extension Assembly {
    final class Shopping: Swinject.Assembly {
        func assemble(container: Container) {
            container.register(ShoppingRepository.self) { resolver in
                ShoppingRepositoryImpl(
                    database: resolver.required(AppDatabase.self),
                    writer: resolver.required(LocalMutationWriter.self)
                )
            }
            .inObjectScope(.container)

            container.register(ObserveShoppingListUseCase.self) { resolver in
                ObserveShoppingListUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(AddShoppingEntryUseCase.self) { resolver in
                AddShoppingEntryUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(SetShoppingEntryCheckedUseCase.self) { resolver in
                SetShoppingEntryCheckedUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(SetShoppingItemCheckedUseCase.self) { resolver in
                SetShoppingItemCheckedUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(UpdateShoppingEntryUseCase.self) { resolver in
                UpdateShoppingEntryUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(RemoveShoppingEntryUseCase.self) { resolver in
                RemoveShoppingEntryUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(ClearCheckedShoppingEntriesUseCase.self) { resolver in
                ClearCheckedShoppingEntriesUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(AddRecipeToShoppingListUseCase.self) { resolver in
                AddRecipeToShoppingListUseCaseImpl(
                    recipeRepository: resolver.required(RecipeRepository.self),
                    shoppingRepository: resolver.required(ShoppingRepository.self),
                    expansionService: resolver.required(RecipeExpansionService.self)
                )
            }
        }
    }
}
