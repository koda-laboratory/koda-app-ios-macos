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

            container.register(RecipePhotoRepository.self) { resolver in
                RecipePhotoRepositoryImpl(
                    database: resolver.required(AppDatabase.self),
                    writer: resolver.required(LocalMutationWriter.self),
                    fileDataSource: resolver.required(RecipeImageFileDataSource.self)
                )
            }
            .inObjectScope(.container)
            container.register(AddRecipePhotoUseCase.self) { resolver in
                AddRecipePhotoUseCaseImpl(
                    repository: resolver.required(RecipePhotoRepository.self),
                    transcoder: ImageIOTranscoder()
                )
            }
            container.register(SetRecipeCoverUseCase.self) { resolver in
                SetRecipeCoverUseCaseImpl(repository: resolver.required(RecipePhotoRepository.self))
            }
            container.register(DeleteRecipePhotoUseCase.self) { resolver in
                DeleteRecipePhotoUseCaseImpl(repository: resolver.required(RecipePhotoRepository.self))
            }

            container.register(RecipeLinkRepository.self) { resolver in
                RecipeLinkRepositoryImpl(
                    database: resolver.required(AppDatabase.self),
                    writer: resolver.required(LocalMutationWriter.self)
                )
            }
            .inObjectScope(.container)
            container.register(ObserveRecipeLinksUseCase.self) { resolver in
                ObserveRecipeLinksUseCaseImpl(repository: resolver.required(RecipeLinkRepository.self))
            }
            container.register(AddRecipeLinkUseCase.self) { resolver in
                AddRecipeLinkUseCaseImpl(repository: resolver.required(RecipeLinkRepository.self))
            }
            container.register(RemoveRecipeLinkUseCase.self) { resolver in
                RemoveRecipeLinkUseCaseImpl(repository: resolver.required(RecipeLinkRepository.self))
            }

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
                addRecipeToShoppingList: container.required(AddRecipeToShoppingListUseCase.self),
                addPhoto: container.required(AddRecipePhotoUseCase.self),
                setCover: container.required(SetRecipeCoverUseCase.self),
                deletePhoto: container.required(DeleteRecipePhotoUseCase.self),
                observeLinks: container.required(ObserveRecipeLinksUseCase.self),
                removeLink: container.required(RemoveRecipeLinkUseCase.self)
            )
        )
    }

    static func makeAddRecipeLinkViewModel(
        recipeID: UUID,
        container: DependencyContainer = .shared
    ) -> AddRecipeLinkViewModel {
        AddRecipeLinkViewModel(recipeID: recipeID, addLink: container.required(AddRecipeLinkUseCase.self))
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
