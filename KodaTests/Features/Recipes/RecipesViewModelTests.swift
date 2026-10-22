import Foundation
import Testing

@testable import Koda

@MainActor
@Suite("Recipes screens")
struct RecipesViewModelTests {
    @Test("Search matches names and ingredients; chips combine; Hace tiempo que no lists forgotten recipes")
    func catalog() async throws {
        let environment = try await FeatureEnvironment.make()
        let chickpeas = try await environment.product("Garbanzos")
        let curry = try await environment.recipe("Curry", products: [chickpeas], mealTypes: [.lunch])
        try await environment.recipes.saveRecipe(
            RecipeInput(name: "Ensalada", mealTypes: [.dinner], timeMinutes: 10, isFavorite: true)
        )
        try await environment.planning.logConsumption(
            NewConsumption(recipeID: curry.id, day: TestClock.thursday.adding(days: -30))
        )

        let viewModel = RecipesViewModel(observeCatalog: environment.observeCatalog, clock: { TestClock.now })
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.catalog.count == 2 })
        #expect(viewModel.forgotten.map(\.id) == [curry.id])

        viewModel.searchText = "garbanzo"
        #expect(viewModel.filtered.map(\.recipe.name) == ["Curry"])
        #expect(viewModel.forgotten.isEmpty)

        viewModel.searchText = ""
        await viewModel.send(.toggleFilter(.quick))
        await viewModel.send(.toggleFilter(.favorites))
        #expect(viewModel.filtered.map(\.recipe.name) == ["Ensalada"])
        await viewModel.send(.toggleFilter(.mealType(.lunch)))
        #expect(viewModel.filtered.isEmpty)
        await viewModel.send(.clearFilters)
        #expect(viewModel.filtered.count == 2)
        await viewModel.send(.newRecipe)
        #expect(viewModel.presentedSheet == .newRecipe)
    }

    @Test("The editor saves a new recipe with ingredients, an included recipe and ordered steps")
    func editorCreate() async throws {
        let environment = try await FeatureEnvironment.make()
        let rice = try await environment.product("Arroz")
        let sauce = try await environment.recipe("Tomate frito")
        let viewModel = RecipeEditorViewModel(
            recipeID: nil,
            useCases: RecipeEditorViewModel.UseCases(
                observeDetail: ObserveRecipeDetailUseCaseImpl(repository: environment.recipes),
                observeProducts: environment.observeProducts,
                observeCatalog: environment.observeCatalog,
                saveRecipe: SaveRecipeWithContentsUseCaseImpl(
                    repository: environment.recipes,
                    expansionService: environment.expansion
                ),
                deleteRecipe: DeleteRecipeUseCaseImpl(repository: environment.recipes)
            )
        )
        await viewModel.send(.appeared)
        await viewModel.send(.save)
        #expect(viewModel.state == .invalidForm)
        #expect(viewModel.showsNameError)

        viewModel.form.name = "Arroz a la cubana"
        viewModel.form.timeText = "45"
        await viewModel.send(.addIngredient(rice))
        viewModel.form.ingredients[0].quantityText = "300"
        await viewModel.send(.addComponent(sauce))
        await viewModel.send(.addStep)
        await viewModel.send(.addStep)
        viewModel.form.steps[0].text = "Segundo"
        viewModel.form.steps[1].text = "Primero"
        await viewModel.send(.moveSteps(IndexSet(integer: 1), 0))
        await viewModel.send(.save)
        #expect(viewModel.state == .completed)

        let catalog = try #require(await firstValue(environment.observeCatalog.execute()))
        let saved = try #require(catalog.first { $0.recipe.name == "Arroz a la cubana" })
        #expect(saved.recipe.timeMinutes == 45)
        #expect(saved.recipe.steps == ["Primero", "Segundo"])
        #expect(saved.ingredientNames == ["Arroz"])
        let detail = try #require(
            await firstValue(
                ObserveRecipeDetailUseCaseImpl(repository: environment.recipes).execute(recipeID: saved.id)
            ) ?? nil
        )
        #expect(detail.components.map(\.childRecipeName) == ["Tomate frito"])
        #expect(detail.ingredients.first?.quantity == 300)
    }

    @Test("Editing loads the recipe, replaces its ingredients and refuses including itself")
    func editorEdit() async throws {
        let environment = try await FeatureEnvironment.make()
        let rice = try await environment.product("Arroz")
        let eggs = try await environment.product("Huevos")
        let recipe = try await environment.recipe("Arroz", products: [rice])
        let viewModel = RecipeEditorViewModel(
            recipeID: recipe.id,
            useCases: RecipeEditorViewModel.UseCases(
                observeDetail: ObserveRecipeDetailUseCaseImpl(repository: environment.recipes),
                observeProducts: environment.observeProducts,
                observeCatalog: environment.observeCatalog,
                saveRecipe: SaveRecipeWithContentsUseCaseImpl(
                    repository: environment.recipes,
                    expansionService: environment.expansion
                ),
                deleteRecipe: DeleteRecipeUseCaseImpl(repository: environment.recipes)
            )
        )
        await viewModel.send(.appeared)
        #expect(viewModel.state == .idle)
        #expect(viewModel.form.ingredients.map(\.productName) == ["Arroz"])
        #expect(await eventually { !viewModel.recipes.isEmpty })
        #expect(viewModel.includableRecipes.isEmpty)

        await viewModel.send(.removeIngredients(IndexSet(integer: 0)))
        await viewModel.send(.addIngredient(eggs))
        await viewModel.send(.save)
        #expect(viewModel.state == .completed)
        #expect(
            try await TestDatabase.count("recipe_ingredients", in: environment.database, where: "deleted_at IS NULL")
                == 1
        )
    }
}
