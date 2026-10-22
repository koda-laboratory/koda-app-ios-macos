import Foundation
import GRDB

@testable import Koda

/// Real repositories and use cases over an in-memory database, for ViewModel and use case tests.
struct FeatureEnvironment {
    let database: AppDatabase
    let writer = LocalMutationWriter()
    let recipes: RecipeRepositoryImpl
    let planning: PlanningRepositoryImpl
    let shopping: ShoppingRepositoryImpl
    let products: ProductRepositoryImpl
    let meRepository: MeRepositoryImpl
    let expansion = RecipeExpansionServiceImpl()
    let syncScheduler = RecordingSyncScheduler()

    static func make() async throws -> FeatureEnvironment {
        try await FeatureEnvironment(database: TestDatabase.make())
    }

    init(database: AppDatabase, meRemote: any MeRemoteDataSource = StubMeRemoteDataSource()) {
        self.database = database
        recipes = RecipeRepositoryImpl(database: database, writer: writer)
        planning = PlanningRepositoryImpl(
            database: database,
            writer: writer,
            remoteDataSource: StubPlanningRemoteDataSource()
        )
        shopping = ShoppingRepositoryImpl(database: database, writer: writer)
        products = ProductRepositoryImpl(database: database, writer: writer)
        meRepository = MeRepositoryImpl(remoteDataSource: meRemote, database: database)
    }

    // MARK: - Use cases

    var observeHousehold: any ObserveHouseholdUseCase { ObserveHouseholdUseCaseImpl(meRepository: meRepository) }
    var observeCatalog: any ObserveRecipeCatalogUseCase { ObserveRecipeCatalogUseCaseImpl(repository: recipes) }
    var observeShoppingList: any ObserveShoppingListUseCase { ObserveShoppingListUseCaseImpl(repository: shopping) }
    var observeFrozenItems: any ObserveFrozenItemsUseCase { ObserveFrozenItemsUseCaseImpl(repository: shopping) }
    var observeProducts: any ObserveProductsUseCase { ObserveProductsUseCaseImpl(repository: products) }
    var observeStores: any ObserveStoresUseCase { ObserveStoresUseCaseImpl(repository: products) }
    var planMeal: any PlanMealUseCase { PlanMealUseCaseImpl(repository: planning) }
    var addRecipeToShopping: any AddRecipeToShoppingListUseCase {
        AddRecipeToShoppingListUseCaseImpl(
            recipeRepository: recipes,
            shoppingRepository: shopping,
            expansionService: expansion
        )
    }
    var loadCandidates: any LoadShoppingCandidatesUseCase {
        LoadShoppingCandidatesUseCaseImpl(
            planningRepository: planning,
            shoppingRepository: shopping,
            recipeRepository: recipes,
            expansionService: expansion
        )
    }

    // MARK: - Fixtures

    @discardableResult
    func product(_ name: String, category: ProductCategory = .food) async throws -> Product {
        try await products.saveProduct(ProductInput(name: name, category: category))
    }

    /// A recipe with one ingredient per product.
    @discardableResult
    func recipe(_ name: String, products: [Product] = [], mealTypes: [MealSlot] = [.dinner]) async throws -> Recipe {
        let recipe = try await recipes.saveRecipe(RecipeInput(name: name, mealTypes: mealTypes))
        for product in products {
            try await recipes.addIngredient(
                RecipeIngredientInput(recipeID: recipe.id, productID: product.id, quantity: 100, unit: "g")
            )
        }
        return recipe
    }

    func outbox() async throws -> [OutboxRecord] {
        try await TestDatabase.outbox(database)
    }
}

/// `/me` without network.
struct StubMeRemoteDataSource: MeRemoteDataSource {
    var settingsResponse: MeHouseholdDTO?

    func fetchMe() async throws(KodaError) -> MeResponseDTO {
        throw KodaError(type: .noInternet, reason: "Offline in tests.")
    }

    func updateSettings(householdID: String, _ body: HouseholdSettingsRequestDTO) async throws(KodaError)
        -> MeHouseholdDTO
    {
        guard let settingsResponse else { throw KodaError(type: .noInternet, reason: "Offline in tests.") }
        return settingsResponse
    }
}

struct StubPlanningRemoteDataSource: PlanningRemoteDataSource {
    func acceptDraft(id: String) async throws(KodaError) -> DraftActionResponseDTO {
        DraftActionResponseDTO(draftId: id, entries: 0)
    }

    func discardDraft(id: String) async throws(KodaError) -> DraftActionResponseDTO {
        DraftActionResponseDTO(draftId: id, entries: 0)
    }
}

/// Polls a main-actor condition (ViewModels observe the database asynchronously).
@MainActor
func eventually(timeout: Duration = .seconds(3), _ condition: @MainActor () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

/// A fixed instant: Thursday 22 October 2026 at 15:00 in Madrid (13:00 UTC).
enum TestClock {
    static let thursday = LocalDay(year: 2026, month: 10, day: 22)
    static let now = ISO8601Timestamp.date(from: "2026-10-22T13:00:00Z") ?? .now
}

/// The first value of a stream (the current database value for observations).
func firstValue<Element: Sendable>(_ stream: AsyncStream<Element>) async -> Element? {
    var iterator = stream.makeAsyncIterator()
    return await iterator.next()
}
