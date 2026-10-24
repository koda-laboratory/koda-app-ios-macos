import Foundation
import Swinject

extension Assembly {
    final class Recipes: Swinject.Assembly {
        func assemble(container: Container) {
            container.register(RecipeRepository.self) { resolver in
                RecipeRepositoryImpl(
                    database: resolver.required(AppDatabase.self),
                    writer: resolver.required(LocalMutationWriter.self)
                )
            }
            .inObjectScope(.container)

            container.register(RecipeExpansionService.self) { _ in RecipeExpansionServiceImpl() }
                .inObjectScope(.container)

            container.register(ObserveRecipesUseCase.self) { resolver in
                ObserveRecipesUseCaseImpl(repository: resolver.required(RecipeRepository.self))
            }
            container.register(ObserveRecipeDetailUseCase.self) { resolver in
                ObserveRecipeDetailUseCaseImpl(repository: resolver.required(RecipeRepository.self))
            }
            container.register(ExpandRecipeUseCase.self) { resolver in
                ExpandRecipeUseCaseImpl(
                    repository: resolver.required(RecipeRepository.self),
                    expansionService: resolver.required(RecipeExpansionService.self)
                )
            }
            container.register(ObserveRecipeCatalogUseCase.self) { resolver in
                ObserveRecipeCatalogUseCaseImpl(repository: resolver.required(RecipeRepository.self))
            }
            container.register(ObserveRecipeStatsUseCase.self) { resolver in
                ObserveRecipeStatsUseCaseImpl(repository: resolver.required(RecipeRepository.self))
            }
            container.register(UpdateRecipeNotesUseCase.self) { resolver in
                UpdateRecipeNotesUseCaseImpl(repository: resolver.required(RecipeRepository.self))
            }
            container.register(SaveRecipeWithContentsUseCase.self) { resolver in
                SaveRecipeWithContentsUseCaseImpl(
                    repository: resolver.required(RecipeRepository.self),
                    expansionService: resolver.required(RecipeExpansionService.self)
                )
            }
            container.register(SaveRecipeUseCase.self) { resolver in
                SaveRecipeUseCaseImpl(repository: resolver.required(RecipeRepository.self))
            }
            container.register(SetRecipeFavoriteUseCase.self) { resolver in
                SetRecipeFavoriteUseCaseImpl(repository: resolver.required(RecipeRepository.self))
            }
            container.register(DeleteRecipeUseCase.self) { resolver in
                DeleteRecipeUseCaseImpl(repository: resolver.required(RecipeRepository.self))
            }
            container.register(AddRecipeIngredientUseCase.self) { resolver in
                AddRecipeIngredientUseCaseImpl(repository: resolver.required(RecipeRepository.self))
            }
            container.register(AddRecipeComponentUseCase.self) { resolver in
                AddRecipeComponentUseCaseImpl(
                    repository: resolver.required(RecipeRepository.self),
                    expansionService: resolver.required(RecipeExpansionService.self)
                )
            }
        }
    }
}

// MARK: - ViewModels

extension Assembly {
    static func makeRecipesViewModel(container: DependencyContainer = .shared) -> RecipesViewModel {
        RecipesViewModel(observeCatalog: container.required(ObserveRecipeCatalogUseCase.self))
    }

    static func makeRecipeDetailViewModel(
        recipeID: UUID,
        container: DependencyContainer = .shared
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            recipeID: recipeID,
            useCases: RecipeDetailViewModel.UseCases(
                observeDetail: container.required(ObserveRecipeDetailUseCase.self),
                observeStats: container.required(ObserveRecipeStatsUseCase.self),
                setFavorite: container.required(SetRecipeFavoriteUseCase.self),
                updateNotes: container.required(UpdateRecipeNotesUseCase.self),
                addRecipeToShoppingList: container.required(AddRecipeToShoppingListUseCase.self)
            )
        )
    }

    static func makeRecipeEditorViewModel(
        recipeID: UUID?,
        container: DependencyContainer = .shared
    ) -> RecipeEditorViewModel {
        RecipeEditorViewModel(
            recipeID: recipeID,
            useCases: RecipeEditorViewModel.UseCases(
                observeDetail: container.required(ObserveRecipeDetailUseCase.self),
                observeProducts: container.required(ObserveProductsUseCase.self),
                observeCatalog: container.required(ObserveRecipeCatalogUseCase.self),
                saveRecipe: container.required(SaveRecipeWithContentsUseCase.self),
                deleteRecipe: container.required(DeleteRecipeUseCase.self)
            )
        )
    }
}
