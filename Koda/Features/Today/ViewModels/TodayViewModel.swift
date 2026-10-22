import Foundation
import Observation

enum TodayState: Sendable, Equatable {
    /// Before the first local read of today's meals.
    case loading
    case ready
}

enum TodaySheet: Sendable, Equatable, Identifiable {
    case planMeal(PlanMealRequest)
    case profile

    var id: String {
        switch self {
        case .planMeal(let request): "plan-\(request.id)"
        case .profile: "profile"
        }
    }
}

enum TodayIntent: Sendable {
    case appeared
    /// Re-evaluates the progress: meals turn "done" when their time passes (the screen sends it every 30 s).
    case tick
    case changeMeal(MealPlanEntry)
    case skipMeal(MealPlanEntry)
    case resolveFrozenItem(FrozenItem)
    case planSuggestion(UUID)
    case openProfile
    case dismissSheet
}

/// Hoy: greeting, the day's progress computed locally from the slot times, meal cards, defrost reminders, the
/// shopping summary, a suggestion and pending drafts. Everything is observed from the local database.
@MainActor
@Observable
final class TodayViewModel: MVIViewModel {
    // MARK: - Properties

    private(set) var state = TodayState.loading
    private(set) var household: HouseholdContext?
    private(set) var meals: [MealPlanEntry] = []
    private(set) var frozenItems: [FrozenItem] = []
    private(set) var shopping: ShoppingList?
    private(set) var drafts: [MealPlanDraft] = []
    private(set) var catalog: [UUID: RecipeCatalogItem] = [:]
    private(set) var now: Date
    var presentedSheet: TodaySheet?
    var toast: Toast?

    /// The use cases Hoy depends on.
    struct UseCases {
        let observeHousehold: any ObserveHouseholdUseCase
        let observeTodayMeals: any ObserveTodayMealsUseCase
        let observeFrozenItems: any ObserveFrozenItemsUseCase
        let observeShoppingList: any ObserveShoppingListUseCase
        let observePendingDrafts: any ObservePendingDraftsUseCase
        let observeRecipeCatalog: any ObserveRecipeCatalogUseCase
        let skipMeal: any SkipMealUseCase
        let resolveFrozenItem: any ResolveFrozenItemUseCase
    }

    @ObservationIgnored private let useCases: UseCases
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var observations: [Task<Void, Never>]?
    @ObservationIgnored private var mealsObservation: Task<Void, Never>?
    @ObservationIgnored private var observedDay: LocalDay?

    // MARK: - Lifecycle

    init(useCases: UseCases, clock: @escaping @Sendable () -> Date = { .now }) {
        self.useCases = useCases
        self.clock = clock
        self.now = clock()
    }

    deinit {
        observations?.forEach { $0.cancel() }
        mealsObservation?.cancel()
    }

    // MARK: - Derived

    var timeZone: TimeZone { household?.household.timeZone ?? .household }
    var today: LocalDay { LocalDay.today(in: timeZone, now: now) }
    var slotTimes: SlotTimes { household?.household.settings.slotTimes ?? .default }

    var progress: TodayProgress {
        TodayProgress(entries: meals, day: today, slotTimes: slotTimes, now: now, timeZone: timeZone)
    }

    /// Frozen products whose defrost reminder time has come ("Descongelar hoy").
    var dueFrozenItems: [FrozenItem] {
        frozenItems.filter { $0.isDue(now: now) }
    }

    /// The forgotten recipe to suggest, unless it is already planned today.
    var suggestion: RecipeCatalogItem? {
        let planned = Set(meals.compactMap(\.recipeID))
        return RecipeSuggestions.forgotten(Array(catalog.values), today: today, limit: 20)
            .first { !planned.contains($0.recipe.id) }
    }

    func recipe(for entry: MealPlanEntry) -> RecipeCatalogItem? {
        entry.recipeID.flatMap { catalog[$0] }
    }

    // MARK: - Intents

    func send(_ intent: TodayIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        case .tick:
            refreshClock()
        case .changeMeal(let entry):
            presentedSheet = .planMeal(.edit(entry))
        case .skipMeal(let entry):
            await skip(entry)
        case .resolveFrozenItem(let item):
            await resolve(item)
        case .planSuggestion(let recipeID):
            presentedSheet = .planMeal(.new(day: today, slot: suggestedSlot(for: recipeID), recipeID: recipeID))
        case .openProfile:
            presentedSheet = .profile
        case .dismissSheet:
            presentedSheet = nil
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observations == nil else { return }
        let households = useCases.observeHousehold.execute()
        let frozen = useCases.observeFrozenItems.execute()
        let shopping = useCases.observeShoppingList.execute()
        let drafts = useCases.observePendingDrafts.execute()
        let catalog = useCases.observeRecipeCatalog.execute()
        observations = [
            Task { [weak self] in
                for await household in households {
                    self?.household = household
                    self?.observeMealsIfNeeded()
                }
            },
            Task { [weak self] in
                for await items in frozen { self?.frozenItems = items }
            },
            Task { [weak self] in
                for await list in shopping { self?.shopping = list }
            },
            Task { [weak self] in
                for await pending in drafts { self?.drafts = pending }
            },
            Task { [weak self] in
                for await items in catalog {
                    self?.catalog = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
                }
            },
        ]
        observeMealsIfNeeded()
    }

    /// (Re)starts the observation of today's meals when the day changes (midnight, time zone from `/me`).
    private func observeMealsIfNeeded() {
        let day = today
        guard day != observedDay else { return }
        observedDay = day
        mealsObservation?.cancel()
        let stream = useCases.observeTodayMeals.execute(day: day)
        mealsObservation = Task { [weak self] in
            for await todayMeals in stream {
                self?.meals = todayMeals.meals
                self?.state = .ready
            }
        }
    }

    private func refreshClock() {
        now = clock()
        observeMealsIfNeeded()
    }

    private func skip(_ entry: MealPlanEntry) async {
        do {
            try await useCases.skipMeal.execute(entryID: entry.id)
            toast = Toast(messageKey: "today.toast.skipped")
        } catch {
            toast = .error(error)
        }
    }

    private func resolve(_ item: FrozenItem) async {
        do {
            try await useCases.resolveFrozenItem.execute(frozenItemID: item.id)
        } catch {
            toast = .error(error)
        }
    }

    private func suggestedSlot(for recipeID: UUID) -> MealSlot {
        catalog[recipeID]?.recipe.mealTypes.first ?? .dinner
    }
}
