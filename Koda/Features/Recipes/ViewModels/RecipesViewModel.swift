import Foundation
import Observation

enum RecipesState: Sendable, Equatable {
    case loading
    case ready
}

/// Filter chips of the catalog.
enum RecipeFilter: Hashable, Sendable {
    case mealType(MealSlot)
    case quick
    case nutrient(Nutrient)
    case favorites

    static let all: [RecipeFilter] =
        [.favorites, .quick] + MealSlot.allCases.map(RecipeFilter.mealType)
        + Nutrient.allCases.map(RecipeFilter.nutrient)

    func matches(_ recipe: Recipe) -> Bool {
        switch self {
        case .mealType(let slot): recipe.mealTypes.contains(slot)
        case .quick: (recipe.timeMinutes ?? .max) < 30
        case .nutrient(let nutrient): recipe.nutrients.contains(nutrient)
        case .favorites: recipe.isFavorite
        }
    }
}

enum RecipesSheet: Sendable, Equatable, Identifiable {
    case newRecipe

    var id: String { "new-recipe" }
}

enum RecipesIntent: Sendable {
    case appeared
    case toggleFilter(RecipeFilter)
    case clearFilters
    case newRecipe
    case dismissSheet
}

/// Recetas: search by name or ingredient, filter chips, "Hace tiempo que no" and the grid.
@MainActor
@Observable
final class RecipesViewModel: MVIViewModel {
    // MARK: - Properties

    private(set) var state = RecipesState.loading
    private(set) var catalog: [RecipeCatalogItem] = []
    private(set) var filters: Set<RecipeFilter> = []
    var searchText = ""
    var presentedSheet: RecipesSheet?

    @ObservationIgnored private let observeCatalog: any ObserveRecipeCatalogUseCase
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var observation: Task<Void, Never>?

    // MARK: - Lifecycle

    init(observeCatalog: any ObserveRecipeCatalogUseCase, clock: @escaping @Sendable () -> Date = { .now }) {
        self.observeCatalog = observeCatalog
        self.clock = clock
    }

    deinit {
        observation?.cancel()
    }

    // MARK: - Derived

    var today: LocalDay { LocalDay.today(now: clock()) }

    /// Recipes matching every selected chip and the search (name or an ingredient).
    var filtered: [RecipeCatalogItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.filter { item in
            guard filters.allSatisfy({ $0.matches(item.recipe) }) else { return false }
            guard !query.isEmpty else { return true }
            return item.recipe.name.localizedStandardContains(query)
                || item.ingredientNames.contains { $0.localizedStandardContains(query) }
        }
    }

    /// "Hace tiempo que no", hidden while searching or filtering.
    var forgotten: [RecipeCatalogItem] {
        guard filters.isEmpty, searchText.isEmpty else { return [] }
        return RecipeSuggestions.forgotten(catalog, today: today)
    }

    // MARK: - Intents

    func send(_ intent: RecipesIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        case .toggleFilter(let filter):
            if filters.contains(filter) {
                filters.remove(filter)
            } else {
                filters.insert(filter)
            }
        case .clearFilters:
            filters = []
        case .newRecipe:
            presentedSheet = .newRecipe
        case .dismissSheet:
            presentedSheet = nil
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observation == nil else { return }
        let stream = observeCatalog.execute()
        observation = Task { [weak self] in
            for await items in stream {
                self?.catalog = items
                self?.state = .ready
            }
        }
    }
}
