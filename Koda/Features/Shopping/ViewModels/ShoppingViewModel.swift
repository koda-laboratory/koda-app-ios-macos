import Foundation
import Observation

enum ShoppingState: Sendable, Equatable {
    case loading
    case ready
}

/// A quick-add suggestion: a catalog product, a recipe or the typed text.
enum ShoppingSuggestion: Sendable, Equatable, Identifiable {
    case product(Product)
    case recipe(Recipe)
    case text(String)

    var id: String {
        switch self {
        case .product(let product): "product-\(product.id)"
        case .recipe(let recipe): "recipe-\(recipe.id)"
        case .text(let text): "text-\(text)"
        }
    }
}

enum ShoppingSheet: Sendable, Equatable, Identifiable {
    /// The first time something is marked as frozen: explain the defrost reminder before the system prompt.
    case notificationsExplanation

    var id: String { "notifications" }
}

enum ShoppingIntent: Sendable {
    case appeared
    /// Tap on a row: have ↔ pending.
    case toggleHave(ShoppingRow)
    /// Snowflake: frozen ↔ pending.
    case toggleFrozen(ShoppingRow)
    case toggleExpanded(UUID)
    case submitQuickAdd
    case pickSuggestion(ShoppingSuggestion)
    case removeRow(ShoppingRow)
    case clearHave
    case enableNotifications
    case dismissSheet
}

/// Compra: the continuous list with the three states, products by category, products shared by several recipes
/// shown once, quick add with product autocomplete, recipe entries item by item, the freezer and "Ya lo tenemos".
@MainActor
@Observable
final class ShoppingViewModel: MVIViewModel {
    /// The use cases Compra depends on.
    struct UseCases {
        let observeShoppingList: any ObserveShoppingListUseCase
        let observeFrozenItems: any ObserveFrozenItemsUseCase
        let observeProducts: any ObserveProductsUseCase
        let observeRecipeCatalog: any ObserveRecipeCatalogUseCase
        let observeHousehold: any ObserveHouseholdUseCase
        let addShoppingEntry: any AddShoppingEntryUseCase
        let addRecipeToShoppingList: any AddRecipeToShoppingListUseCase
        let setEntryStatus: any SetShoppingEntryStatusUseCase
        let setItemStatus: any SetShoppingItemStatusUseCase
        let removeEntry: any RemoveShoppingEntryUseCase
        let clearHave: any ClearCheckedShoppingEntriesUseCase
        let getNotificationAuthorization: any GetNotificationAuthorizationUseCase
        let requestNotificationAuthorization: any RequestNotificationAuthorizationUseCase
    }

    // MARK: - Properties

    private(set) var state = ShoppingState.loading
    private(set) var entries: [ShoppingEntry] = []
    private(set) var frozenItems: [FrozenItem] = []
    private(set) var products: [Product] = []
    private(set) var recipes: [Recipe] = []
    private(set) var household: HouseholdContext?
    private(set) var expandedEntryIDs: Set<UUID> = []
    var quickAddText = ""
    var presentedSheet: ShoppingSheet?
    var toast: Toast?

    @ObservationIgnored private let useCases: UseCases
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var observations: [Task<Void, Never>]?

    // MARK: - Lifecycle

    init(useCases: UseCases, clock: @escaping @Sendable () -> Date = { .now }) {
        self.useCases = useCases
        self.clock = clock
    }

    deinit {
        observations?.forEach { $0.cancel() }
    }

    // MARK: - Derived

    var cycle: ShoppingCycle {
        let timeZone = household?.household.timeZone ?? .household
        return ShoppingCycle(
            today: LocalDay.today(in: timeZone, now: clock()),
            shoppingWeekday: household?.household.settings.shoppingWeekday ?? 5
        )
    }

    func layout(
        categoryTitle: (ProductCategory) -> String,
        otherTitle: String,
        quantity: (Double?, String?) -> String
    ) -> ShoppingLayout {
        ShoppingLayout(
            entries: entries,
            frozenItems: frozenItems,
            categoryTitle: categoryTitle,
            otherTitle: otherTitle,
            quantity: quantity
        )
    }

    /// Autocomplete for the quick-add field: matching products, then recipes, then the text itself.
    var suggestions: [ShoppingSuggestion] {
        let query = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let matchingProducts = products.filter { $0.name.localizedStandardContains(query) }.prefix(5)
        let matchingRecipes = recipes.filter { $0.name.localizedStandardContains(query) }.prefix(3)
        var result = matchingProducts.map(ShoppingSuggestion.product) + matchingRecipes.map(ShoppingSuggestion.recipe)
        if !products.contains(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame }) {
            result.append(.text(query))
        }
        return result
    }

    // MARK: - Intents

    func send(_ intent: ShoppingIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        case .toggleHave(let row):
            await setStatus(row.status.togglingHave, for: row)
        case .toggleFrozen(let row):
            await setStatus(row.status.togglingFrozen, for: row)
        case .toggleExpanded(let id):
            if expandedEntryIDs.contains(id) {
                expandedEntryIDs.remove(id)
            } else {
                expandedEntryIDs.insert(id)
            }
        case .submitQuickAdd:
            await submitQuickAdd()
        case .pickSuggestion(let suggestion):
            await add(suggestion)
        case .removeRow(let row):
            await remove(row)
        case .clearHave:
            await clearHave()
        case .enableNotifications:
            presentedSheet = nil
            _ = try? await useCases.requestNotificationAuthorization.execute()
        case .dismissSheet:
            presentedSheet = nil
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observations == nil else { return }
        let list = useCases.observeShoppingList.execute()
        let frozen = useCases.observeFrozenItems.execute()
        let products = useCases.observeProducts.execute()
        let catalog = useCases.observeRecipeCatalog.execute()
        let households = useCases.observeHousehold.execute()
        observations = [
            Task { [weak self] in
                for await list in list {
                    guard let self else { return }
                    self.entries = list.entries
                    if self.state == .loading {
                        // Recipe entries start expanded, as in the approved mockup.
                        self.expandedEntryIDs = Set(list.entries.filter { $0.kind == .recipe }.map(\.id))
                    }
                    self.state = .ready
                }
            },
            Task { [weak self] in
                for await items in frozen { self?.frozenItems = items }
            },
            Task { [weak self] in
                for await items in products { self?.products = items }
            },
            Task { [weak self] in
                for await items in catalog { self?.recipes = items.map(\.recipe) }
            },
            Task { [weak self] in
                for await household in households { self?.household = household }
            },
        ]
    }

    private func setStatus(_ status: ShoppingItemStatus, for row: ShoppingRow) async {
        do {
            // A shared row ("Huevos" in two recipes) changes every entry behind it.
            for target in row.targets {
                switch target {
                case .entry(let id):
                    try await useCases.setEntryStatus.execute(entryID: id, status: status)
                case .item(_, let itemID):
                    try await useCases.setItemStatus.execute(itemID: itemID, status: status)
                case .shared:
                    continue
                }
            }
        } catch {
            toast = .error(error)
            return
        }
        if status == .frozen, await useCases.getNotificationAuthorization.execute() == .notDetermined {
            presentedSheet = .notificationsExplanation
        }
    }

    private func submitQuickAdd() async {
        let text = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let product = products.first(where: { $0.name.caseInsensitiveCompare(text) == .orderedSame }) {
            await add(.product(product))
        } else {
            await add(.text(text))
        }
    }

    private func add(_ suggestion: ShoppingSuggestion) async {
        do {
            switch suggestion {
            case .product(let product):
                try await useCases.addShoppingEntry.execute(
                    NewShoppingEntry(item: .product(product.id), quantity: nil, unit: nil)
                )
            case .recipe(let recipe):
                try await useCases.addRecipeToShoppingList.execute(
                    recipeID: recipe.id,
                    servings: nil,
                    source: .manual,
                    mealPlanEntryID: nil
                )
            case .text(let text):
                try await useCases.addShoppingEntry.execute(NewShoppingEntry(item: .text(text)))
            }
            quickAddText = ""
        } catch {
            toast = .error(error)
        }
    }

    private func remove(_ row: ShoppingRow) async {
        guard case .entry(let id) = row.source else { return }
        do {
            try await useCases.removeEntry.execute(entryID: id)
        } catch {
            toast = .error(error)
        }
    }

    private func clearHave() async {
        do {
            try await useCases.clearHave.execute()
        } catch {
            toast = .error(error)
        }
    }
}
