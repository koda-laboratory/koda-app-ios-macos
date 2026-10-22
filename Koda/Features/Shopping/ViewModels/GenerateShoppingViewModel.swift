import Foundation
import Observation

enum GenerateShoppingState: Sendable, Equatable {
    case loading
    case ready
    case adding
    case completed(added: Int)

    var isBusy: Bool { self == .loading || self == .adding }
}

enum GenerateShoppingIntent: Sendable {
    case appeared
    case setFrom(LocalDay)
    case setThrough(LocalDay)
    case selectQuickRange(ShoppingCycle.QuickRange)
    case toggle(UUID)
    case add
}

/// "Generar compra": proposes the range from the household shopping day (Sat → Fri for Friday), lists the planned
/// recipes in it and adds the selected ones as recipe entries linked to their planned meal (never twice).
@MainActor
@Observable
final class GenerateShoppingViewModel: MVIViewModel {
    // MARK: - Properties

    private(set) var state = GenerateShoppingState.loading
    private(set) var candidates: [ShoppingCandidate] = []
    private(set) var from: LocalDay
    private(set) var through: LocalDay
    private(set) var quickRange: ShoppingCycle.QuickRange? = .untilNextShoppingDay
    private(set) var shoppingWeekday = 5
    private(set) var selectedIDs: Set<UUID> = []
    var toast: Toast?

    @ObservationIgnored private let loadCandidates: any LoadShoppingCandidatesUseCase
    @ObservationIgnored private let addRecipeToShoppingList: any AddRecipeToShoppingListUseCase
    @ObservationIgnored private let observeHousehold: any ObserveHouseholdUseCase
    @ObservationIgnored private let clock: @Sendable () -> Date
    /// Selections the user changed by hand, kept when the range reloads.
    @ObservationIgnored private var deselectedIDs: Set<UUID> = []

    // MARK: - Lifecycle

    init(
        loadCandidates: any LoadShoppingCandidatesUseCase,
        addRecipeToShoppingList: any AddRecipeToShoppingListUseCase,
        observeHousehold: any ObserveHouseholdUseCase,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.loadCandidates = loadCandidates
        self.addRecipeToShoppingList = addRecipeToShoppingList
        self.observeHousehold = observeHousehold
        self.clock = clock
        let cycle = ShoppingCycle(today: LocalDay.today(now: clock()), shoppingWeekday: 5)
        from = cycle.from
        through = cycle.through
    }

    // MARK: - Derived

    var today: LocalDay { LocalDay.today(now: clock()) }
    var cycle: ShoppingCycle { ShoppingCycle(today: today, shoppingWeekday: shoppingWeekday) }
    /// Candidates that will be added.
    var toAdd: [ShoppingCandidate] {
        candidates.filter { !$0.isAlreadyOnList && selectedIDs.contains($0.id) }
    }

    // MARK: - Intents

    func send(_ intent: GenerateShoppingIntent) async {
        switch intent {
        case .appeared:
            guard state == .loading else { return }
            await loadHouseholdCycle()
            await reload()
        case .setFrom(let day):
            from = day
            if through < day { through = day }
            quickRange = nil
            await reload()
        case .setThrough(let day):
            through = day
            if from > day { from = day }
            quickRange = nil
            await reload()
        case .selectQuickRange(let range):
            let days = cycle.range(range, today: today)
            from = days.lowerBound
            through = days.upperBound
            quickRange = range
            await reload()
        case .toggle(let id):
            toggle(id)
        case .add:
            await add()
        }
    }

    // MARK: - Private Methods

    private func loadHouseholdCycle() async {
        for await household in observeHousehold.execute() {
            shoppingWeekday = household?.household.settings.shoppingWeekday ?? 5
            break
        }
        from = cycle.from
        through = cycle.through
    }

    private func reload() async {
        do {
            candidates = try await loadCandidates.execute(from: from, through: through)
            selectedIDs = Set(candidates.filter { !$0.isAlreadyOnList && !deselectedIDs.contains($0.id) }.map(\.id))
        } catch {
            candidates = []
            selectedIDs = []
            toast = .error(error)
        }
        if state == .loading || state == .ready { state = .ready }
    }

    private func toggle(_ id: UUID) {
        guard let candidate = candidates.first(where: { $0.id == id }), !candidate.isAlreadyOnList else { return }
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
            deselectedIDs.insert(id)
        } else {
            selectedIDs.insert(id)
            deselectedIDs.remove(id)
        }
    }

    private func add() async {
        guard state == .ready else { return }
        let entries = toAdd
        guard !entries.isEmpty else { return }
        state = .adding
        var added = 0
        for candidate in entries {
            guard let recipeID = candidate.entry.recipeID else { continue }
            do {
                try await addRecipeToShoppingList.execute(
                    recipeID: recipeID,
                    servings: candidate.entry.servings,
                    source: .plan,
                    mealPlanEntryID: candidate.entry.id
                )
                added += 1
            } catch {
                toast = .error(error)
            }
        }
        state = .completed(added: added)
    }
}
