import AppIntents
import CoreSpotlight
import Foundation

/// Keeps Spotlight (recipes) and the Siri phrase parameters (recipes and products in "Apunta leche en Koda") in
/// step with the local database, including changes that arrive by sync.
protocol IntentIndexing: Sendable {
    func start() async
    /// Signing out removes the household's recipes from Spotlight.
    func stopAndClear() async
}

actor IntentIndexingService: IntentIndexing {
    private let observeRecipes: any ObserveRecipeCatalogUseCase
    private let observeProducts: any ObserveProductsUseCase
    private let loggerService: any LoggerService

    private var observation: Task<Void, Never>?
    private var indexedRecipeIDs: Set<UUID> = []
    private var lastRecipes: [RecipeEntityIndexKey] = []

    init(
        observeRecipes: any ObserveRecipeCatalogUseCase,
        observeProducts: any ObserveProductsUseCase,
        loggerService: any LoggerService
    ) {
        self.observeRecipes = observeRecipes
        self.observeProducts = observeProducts
        self.loggerService = loggerService
    }

    func start() {
        guard observation == nil else { return }
        let recipes = observeRecipes.execute()
        let products = observeProducts.execute()
        observation = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await catalog in recipes { await self?.index(catalog.map(\.recipe)) }
                }
                group.addTask {
                    // Product names are phrase parameters ("Apunta \(product) en Koda").
                    for await _ in products { KodaShortcuts.updateAppShortcutParameters() }
                }
            }
        }
    }

    func stopAndClear() async {
        observation?.cancel()
        observation = nil
        indexedRecipeIDs = []
        lastRecipes = []
        try? await CSSearchableIndex.default().deleteAppEntities(ofType: RecipeEntity.self)
    }

    // MARK: - Private Methods

    private func index(_ recipes: [Recipe]) async {
        let keys = recipes.map(RecipeEntityIndexKey.init)
        guard keys != lastRecipes else { return }
        lastRecipes = keys
        let entities = recipes.map(RecipeEntity.init)
        let ids = Set(recipes.map(\.id))
        let removed = indexedRecipeIDs.subtracting(ids)
        do {
            try await CSSearchableIndex.default().indexAppEntities(entities)
            if !removed.isEmpty {
                try await CSSearchableIndex.default().deleteAppEntities(
                    identifiedBy: Array(removed),
                    ofType: RecipeEntity.self
                )
            }
            indexedRecipeIDs = ids
        } catch {
            loggerService.warning("Spotlight indexing failed.")
        }
        KodaShortcuts.updateAppShortcutParameters()
    }
}

/// What Spotlight shows of a recipe; reindexing is skipped when none of it changed.
private struct RecipeEntityIndexKey: Equatable, Sendable {
    let id: UUID
    let name: String
    let minutes: Int?

    init(recipe: Recipe) {
        id = recipe.id
        name = recipe.name
        minutes = recipe.displayMinutes
    }
}
