import Foundation
import Observation

enum PlanMealState: Sendable, Equatable {
    case idle
    case invalidForm
    case saving
    case completed

    var isSaving: Bool { self == .saving }
}

enum PlanMealIntent: Sendable {
    case appeared
    case selectRecipe(UUID)
    case save
    case delete
}

/// Plans a new meal or changes an existing one ("Cambiar", "Mover"): recipe or free text, day, slot, time.
@MainActor
@Observable
final class PlanMealViewModel: FormViewModel {
    // MARK: - Properties

    let request: PlanMealRequest
    private(set) var state = PlanMealState.idle
    private(set) var recipes: [RecipeCatalogItem] = []
    private(set) var slotTimes = SlotTimes.default
    var form: PlanMealFormState
    var searchText = ""
    var toast: Toast?

    @ObservationIgnored private let planMeal: any PlanMealUseCase
    @ObservationIgnored private let updatePlannedMeal: any UpdatePlannedMealUseCase
    @ObservationIgnored private let removePlannedMeal: any RemovePlannedMealUseCase
    @ObservationIgnored private let observeRecipeCatalog: any ObserveRecipeCatalogUseCase
    @ObservationIgnored private let observeHousehold: any ObserveHouseholdUseCase
    @ObservationIgnored private var observations: [Task<Void, Never>]?

    // MARK: - Lifecycle

    init(
        request: PlanMealRequest,
        planMeal: any PlanMealUseCase,
        updatePlannedMeal: any UpdatePlannedMealUseCase,
        removePlannedMeal: any RemovePlannedMealUseCase,
        observeRecipeCatalog: any ObserveRecipeCatalogUseCase,
        observeHousehold: any ObserveHouseholdUseCase
    ) {
        self.request = request
        self.planMeal = planMeal
        self.updatePlannedMeal = updatePlannedMeal
        self.removePlannedMeal = removePlannedMeal
        self.observeRecipeCatalog = observeRecipeCatalog
        self.observeHousehold = observeHousehold
        switch request {
        case .new(let day, let slot, let recipeID):
            form = PlanMealFormState(day: day, slot: slot, recipeID: recipeID, time: SlotTimes.default[slot])
        case .edit(let entry):
            form = PlanMealFormState(
                day: entry.day,
                slot: entry.slot,
                kind: entry.isRecipe ? .recipe : .text,
                recipeID: entry.recipeID,
                freeText: entry.freeText ?? "",
                usesCustomTime: entry.scheduledTime != nil,
                time: entry.scheduledTime ?? SlotTimes.default[entry.slot],
                servings: entry.servings ?? 2
            )
        }
    }

    deinit {
        observations?.forEach { $0.cancel() }
    }

    // MARK: - Derived

    var isEditing: Bool {
        if case .edit = request { return true }
        return false
    }

    var selectedRecipe: Recipe? {
        form.recipeID.flatMap { id in recipes.first { $0.id == id }?.recipe }
    }

    /// Recipes matching the search, those suited to the slot first.
    var filteredRecipes: [RecipeCatalogItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching =
            query.isEmpty
            ? recipes
            : recipes.filter { $0.recipe.name.localizedStandardContains(query) }
        return matching.sorted { lhs, rhs in
            let lhsFits = lhs.recipe.mealTypes.contains(form.slot)
            let rhsFits = rhs.recipe.mealTypes.contains(form.slot)
            if lhsFits != rhsFits { return lhsFits }
            return lhs.recipe.name.localizedCaseInsensitiveCompare(rhs.recipe.name) == .orderedAscending
        }
    }

    var defaultTime: LocalTime { slotTimes[form.slot] }
    var showsRecipeError: Bool { state == .invalidForm && form.kind == .recipe && form.recipeID == nil }
    var showsTextError: Bool { state == .invalidForm && form.kind == .text && form.trimmedText.isEmpty }

    // MARK: - Intents

    func send(_ intent: PlanMealIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        case .selectRecipe(let id):
            form.kind = .recipe
            form.recipeID = id
            if state == .invalidForm { state = .idle }
        case .save:
            await save()
        case .delete:
            await delete()
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observations == nil else { return }
        let catalog = observeRecipeCatalog.execute()
        let households = observeHousehold.execute()
        observations = [
            Task { [weak self] in
                for await items in catalog { self?.recipes = items }
            },
            Task { [weak self] in
                for await household in households {
                    guard let self, let household else { continue }
                    self.slotTimes = household.household.settings.slotTimes
                    if !self.form.usesCustomTime { self.form.time = self.slotTimes[self.form.slot] }
                }
            },
        ]
    }

    private func save() async {
        guard !state.isSaving else { return }
        guard form.isValid else {
            state = .invalidForm
            return
        }
        state = .saving
        let recipeID = form.kind == .recipe ? form.recipeID : nil
        let freeText = form.kind == .text ? form.trimmedText : nil
        do {
            switch request {
            case .new:
                try await planMeal.execute(
                    NewMealPlanEntry(
                        day: form.day,
                        slot: form.slot,
                        recipeID: recipeID,
                        freeText: freeText,
                        servings: recipeID == nil ? nil : form.servings,
                        scheduledTime: form.scheduledTime
                    )
                )
            case .edit(let entry):
                try await updatePlannedMeal.execute(
                    entryID: entry.id,
                    MealPlanEntryUpdate(
                        day: form.day,
                        slot: form.slot,
                        recipeID: recipeID,
                        freeText: freeText,
                        servings: recipeID == nil ? nil : form.servings,
                        scheduledTime: form.scheduledTime
                    )
                )
            }
            state = .completed
        } catch {
            state = .idle
            toast = .error(error)
        }
    }

    private func delete() async {
        guard case .edit(let entry) = request, !state.isSaving else { return }
        state = .saving
        do {
            try await removePlannedMeal.execute(entryID: entry.id)
            state = .completed
        } catch {
            state = .idle
            toast = .error(error)
        }
    }
}
