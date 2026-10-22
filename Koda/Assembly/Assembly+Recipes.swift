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
