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
            container.register(SetShoppingEntryStatusUseCase.self) { resolver in
                SetShoppingEntryStatusUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(SetShoppingItemStatusUseCase.self) { resolver in
                SetShoppingItemStatusUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(ObserveFrozenItemsUseCase.self) { resolver in
                ObserveFrozenItemsUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(ResolveFrozenItemUseCase.self) { resolver in
                ResolveFrozenItemUseCaseImpl(repository: resolver.required(ShoppingRepository.self))
            }
            container.register(LoadShoppingCandidatesUseCase.self) { resolver in
                LoadShoppingCandidatesUseCaseImpl(
                    planningRepository: resolver.required(PlanningRepository.self),
                    shoppingRepository: resolver.required(ShoppingRepository.self),
                    recipeRepository: resolver.required(RecipeRepository.self),
                    expansionService: resolver.required(RecipeExpansionService.self)
                )
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

// MARK: - ViewModels

extension Assembly {
    static func makeShoppingViewModel(container: DependencyContainer = .shared) -> ShoppingViewModel {
        ShoppingViewModel(
            useCases: ShoppingViewModel.UseCases(
                observeShoppingList: container.required(ObserveShoppingListUseCase.self),
                observeFrozenItems: container.required(ObserveFrozenItemsUseCase.self),
                observeProducts: container.required(ObserveProductsUseCase.self),
                observeRecipeCatalog: container.required(ObserveRecipeCatalogUseCase.self),
                observeHousehold: container.required(ObserveHouseholdUseCase.self),
                addShoppingEntry: container.required(AddShoppingEntryUseCase.self),
                addRecipeToShoppingList: container.required(AddRecipeToShoppingListUseCase.self),
                setEntryStatus: container.required(SetShoppingEntryStatusUseCase.self),
                setItemStatus: container.required(SetShoppingItemStatusUseCase.self),
                removeEntry: container.required(RemoveShoppingEntryUseCase.self),
                clearHave: container.required(ClearCheckedShoppingEntriesUseCase.self),
                getNotificationAuthorization: container.required(GetNotificationAuthorizationUseCase.self),
                requestNotificationAuthorization: container.required(RequestNotificationAuthorizationUseCase.self)
            )
        )
    }

    static func makeGenerateShoppingViewModel(container: DependencyContainer = .shared) -> GenerateShoppingViewModel {
        GenerateShoppingViewModel(
            loadCandidates: container.required(LoadShoppingCandidatesUseCase.self),
            addRecipeToShoppingList: container.required(AddRecipeToShoppingListUseCase.self),
            observeHousehold: container.required(ObserveHouseholdUseCase.self)
        )
    }
}
