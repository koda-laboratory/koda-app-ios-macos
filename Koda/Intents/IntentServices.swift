import AppIntents
import Foundation

/// The use cases App Intents and entity queries reach through `@Dependency`. Registered once in `KodaApp.init`
/// (cold Siri and Spotlight launches never show a view), resolved from the same Swinject container as the UI,
/// so intents read and write only the local database and leave sync to the `SyncEngine`.
struct IntentServices: Sendable {
    let observeHousehold: any ObserveHouseholdUseCase
    let observeTodayMeals: any ObserveTodayMealsUseCase
    let observeShoppingList: any ObserveShoppingListUseCase
    let observeRecipes: any ObserveRecipeCatalogUseCase
    let observeProducts: any ObserveProductsUseCase
    let addShoppingEntry: any AddShoppingEntryUseCase
    let addRecipeToShoppingList: any AddRecipeToShoppingListUseCase
    let setEntryStatus: any SetShoppingEntryStatusUseCase
    let setItemStatus: any SetShoppingItemStatusUseCase

    static func live(container: DependencyContainer = .shared) -> IntentServices {
        IntentServices(
            observeHousehold: container.required(ObserveHouseholdUseCase.self),
            observeTodayMeals: container.required(ObserveTodayMealsUseCase.self),
            observeShoppingList: container.required(ObserveShoppingListUseCase.self),
            observeRecipes: container.required(ObserveRecipeCatalogUseCase.self),
            observeProducts: container.required(ObserveProductsUseCase.self),
            addShoppingEntry: container.required(AddShoppingEntryUseCase.self),
            addRecipeToShoppingList: container.required(AddRecipeToShoppingListUseCase.self),
            setEntryStatus: container.required(SetShoppingEntryStatusUseCase.self),
            setItemStatus: container.required(SetShoppingItemStatusUseCase.self)
        )
    }

    /// Registers the services for every intent and query. Call from `App.init()`, before any intent can run.
    static func register() {
        AppDependencyManager.shared.add(dependency: IntentServices.live())
    }

    // MARK: - Reads

    /// The household's today (its time zone, not the device's).
    func today() async -> LocalDay {
        let household = await observeHousehold.execute().first { _ in true } ?? nil
        return LocalDay.today(in: household?.household.timeZone ?? .household)
    }

    func slotTimes() async -> SlotTimes {
        let household = await observeHousehold.execute().first { _ in true } ?? nil
        return household?.household.settings.slotTimes ?? .default
    }

    func todayMeals() async -> TodayMeals? {
        await observeTodayMeals.execute(day: await today()).first { _ in true }
    }

    func shoppingList() async -> ShoppingList? {
        await observeShoppingList.execute().first { _ in true }
    }

    func recipes() async -> [Recipe] {
        await observeRecipes.execute().first { _ in true }?.map(\.recipe) ?? []
    }

    func products() async -> [Product] {
        await observeProducts.execute().first { _ in true } ?? []
    }
}

/// Lets foreground intents (open a recipe, focus the shopping quick add) drive the app's navigation.
@MainActor
final class IntentNavigator {
    static let shared = IntentNavigator()

    /// Set by `AppLifecycleCoordinator` when it is created at launch.
    weak var router: AppRouter?
}
