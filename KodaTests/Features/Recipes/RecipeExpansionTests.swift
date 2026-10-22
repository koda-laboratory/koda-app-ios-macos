import Foundation
import Testing

@testable import Koda

@Suite("Recipe expansion (nesting, cycles, aggregation)")
struct RecipeExpansionTests {
    // Products
    private static let chicken = UUID()
    private static let potato = UUID()
    private static let oil = UUID()
    private static let salt = UUID()
    // Recipes
    private static let roast = UUID()
    private static let fries = UUID()
    private static let sauce = UUID()

    private let service = RecipeExpansionServiceImpl()

    private static func ingredient(_ product: UUID, _ name: String, _ quantity: Double?, _ unit: String?)
        -> RecipeGraph.Ingredient
    {
        RecipeGraph.Ingredient(productID: product, productName: name, quantity: quantity, unit: unit, position: 0)
    }

    /// Pollo al horno (2 servings) includes Patatas al airfryer ×1.5 and Salsa ×0.5; Patatas includes Salsa ×1.
    private static func graph() -> RecipeGraph {
        RecipeGraph(
            recipes: [
                roast: .init(id: roast, name: "Pollo al horno", servings: 2),
                fries: .init(id: fries, name: "Patatas al airfryer", servings: 2),
                sauce: .init(id: sauce, name: "Salsa", servings: 1),
            ],
            ingredients: [
                roast: [ingredient(chicken, "Pollo", 500, "g"), ingredient(oil, "Aceite", 10, "ml")],
                fries: [ingredient(potato, "Patatas", 400, "g"), ingredient(oil, "Aceite", 5, "ml")],
                sauce: [ingredient(oil, "Aceite", 20, "ml"), ingredient(salt, "Sal", nil, nil)],
            ],
            components: [
                roast: [
                    .init(childRecipeID: fries, servingsFactor: 1.5, position: 0),
                    .init(childRecipeID: sauce, servingsFactor: 0.5, position: 1),
                ],
                fries: [.init(childRecipeID: sauce, servingsFactor: 1, position: 0)],
            ]
        )
    }

    private func quantity(_ expansion: RecipeExpansion, _ product: UUID, unit: String? = nil) -> Double? {
        expansion.items.first { $0.productID == product && $0.unit == unit }?.quantity
    }

    @Test("Nested recipes multiply servings factors along the path and aggregate by product and unit")
    func nestedAggregation() throws {
        let expansion = try service.expand(recipeID: Self.roast, servings: nil, in: Self.graph())

        #expect(expansion.tree.map(\.name) == ["Pollo al horno", "Patatas al airfryer", "Salsa", "Salsa"])
        #expect(expansion.tree.map(\.depth) == [0, 1, 2, 1])
        #expect(expansion.tree.map(\.servingsFactor) == [1, 1.5, 1.5, 0.5])
        #expect(expansion.label == "Pollo al horno + Patatas al airfryer + Salsa + Salsa")
        #expect(quantity(expansion, Self.chicken, unit: "g") == 500)
        #expect(quantity(expansion, Self.potato, unit: "g") == 600)
        // 10 + 5×1.5 + 20×1.5 (salsa inside patatas) + 20×0.5 (salsa directly) = 57.5 ml
        #expect(quantity(expansion, Self.oil, unit: "ml") == 57.5)
        #expect(expansion.items.first { $0.productID == Self.salt }?.quantity == nil)
        #expect(expansion.items.first { $0.productID == Self.oil }?.recipeIDs == [Self.roast, Self.fries, Self.sauce])
        #expect(expansion.items.map(\.productName) == ["Aceite", "Patatas", "Pollo", "Sal"])
    }

    @Test(
        "Requested servings scale relative to the root recipe",
        arguments: [(nil as Double?, 500.0), (2, 500), (4, 1000), (1, 250)]
    )
    func servingsScale(servings: Double?, chicken: Double) throws {
        let expansion = try service.expand(recipeID: Self.roast, servings: servings, in: Self.graph())
        #expect(quantity(expansion, Self.chicken, unit: "g") == chicken)
    }

    @Test("Cycles stop at the repeated recipe instead of looping")
    func cyclesTerminate() throws {
        var graph = Self.graph()
        graph.components[Self.sauce] = [.init(childRecipeID: Self.roast, servingsFactor: 1, position: 0)]

        let expansion = try service.expand(recipeID: Self.roast, servings: nil, in: graph)

        #expect(expansion.tree.filter { $0.recipeID == Self.roast }.count == 1)
        #expect(expansion.tree.count == 4)
    }

    @Test("Same product in different units stays in separate lines")
    func unitsAreNotMerged() throws {
        var graph = Self.graph()
        graph.ingredients[Self.sauce]?.append(Self.ingredient(Self.oil, "Aceite", 1, "cucharada"))

        let expansion = try service.expand(recipeID: Self.sauce, servings: nil, in: graph)

        #expect(quantity(expansion, Self.oil, unit: "ml") == 20)
        #expect(quantity(expansion, Self.oil, unit: "cucharada") == 1)
    }

    @Test("Unknown or deleted recipes are reported")
    func unknownRecipe() {
        #expect(throws: KodaError.self) { try service.expand(recipeID: UUID(), servings: nil, in: Self.graph()) }
    }

    @Test(
        "Cycle detection for new components",
        arguments: [
            (RecipeExpansionTests.roast, RecipeExpansionTests.fries, false),
            (RecipeExpansionTests.fries, RecipeExpansionTests.roast, true),
            (RecipeExpansionTests.sauce, RecipeExpansionTests.roast, true),
            (RecipeExpansionTests.sauce, RecipeExpansionTests.fries, true),
            (RecipeExpansionTests.roast, RecipeExpansionTests.roast, true),
        ]
    )
    func cycleDetection(parent: UUID, child: UUID, createsCycle: Bool) {
        #expect(service.wouldCreateCycle(parentID: parent, childID: child, in: Self.graph()) == createsCycle)
    }
}

@Suite("Adding a recipe to the shopping list")
struct AddRecipeToShoppingListTests {
    @Test("Writes one recipe entry with its flattened products in one transaction")
    func addsOneEntryWithItems() async throws {
        let database = try await TestDatabase.make()
        let writer = LocalMutationWriter()
        let products = ProductRepositoryImpl(database: database, writer: writer)
        let recipes = RecipeRepositoryImpl(database: database, writer: writer)
        let shopping = ShoppingRepositoryImpl(database: database, writer: writer)

        let chicken = try await products.saveProduct(ProductInput(name: "Pollo", category: .food))
        let potato = try await products.saveProduct(ProductInput(name: "Patatas", category: .food))
        let roast = try await recipes.saveRecipe(RecipeInput(name: "Pollo al horno", servings: 2))
        let fries = try await recipes.saveRecipe(RecipeInput(name: "Patatas al airfryer", servings: 2))
        try await recipes.addIngredient(
            RecipeIngredientInput(recipeID: roast.id, productID: chicken.id, quantity: 500, unit: "g")
        )
        try await recipes.addIngredient(
            RecipeIngredientInput(recipeID: fries.id, productID: potato.id, quantity: 400, unit: "g")
        )
        let addComponent = AddRecipeComponentUseCaseImpl(
            repository: recipes,
            expansionService: RecipeExpansionServiceImpl()
        )
        try await addComponent.execute(parentID: roast.id, childID: fries.id, servingsFactor: 1)
        await #expect(throws: KodaError.self) {
            try await addComponent.execute(parentID: fries.id, childID: roast.id, servingsFactor: 1)
        }
        let outboxBefore = try await TestDatabase.count("outbox", in: database)

        let useCase = AddRecipeToShoppingListUseCaseImpl(
            recipeRepository: recipes,
            shoppingRepository: shopping,
            expansionService: RecipeExpansionServiceImpl()
        )
        let entry = try await useCase.execute(recipeID: roast.id, servings: 4, source: .manual, mealPlanEntryID: nil)

        #expect(entry.kind == .recipe)
        #expect(entry.title == "Pollo al horno + Patatas al airfryer")
        #expect(entry.quantity == 4)
        #expect(entry.unit == "servings")
        #expect(Set(entry.items.map(\.productName)) == ["Pollo", "Patatas"])
        #expect(entry.items.first { $0.productID == chicken.id }?.quantity == 1000)
        #expect(try await TestDatabase.count("outbox", in: database) == outboxBefore + 3)

        var lists = ObserveShoppingListUseCaseImpl(repository: shopping).execute().makeAsyncIterator()
        let list = try #require(await lists.next())
        #expect(list.sections.map(\.group) == [.recipes])
        #expect(list.sections.first?.entries.first?.items.count == 2)
    }
}
