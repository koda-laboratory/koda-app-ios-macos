import Foundation
import Observation

enum RecipeDetailState: Sendable, Equatable {
    case loading
    case loaded
    /// Deleted here or on another device.
    case missing
}

/// Autosave of the notes: no save button, saved on focus loss and 1 s after the last keystroke.
enum RecipeNotesState: Sendable, Equatable {
    case saved
    case editing
    case saving
}

enum RecipeDetailSheet: Sendable, Equatable, Identifiable {
    case planMeal(PlanMealRequest)
    case edit

    var id: String {
        switch self {
        case .planMeal(let request): "plan-\(request.id)"
        case .edit: "edit"
        }
    }
}

enum RecipeDetailIntent: Sendable {
    case appeared
    case notesChanged(String)
    case notesFocusChanged(Bool)
    case toggleFavorite
    case addToShopping
    case planMeal
    case edit
    case dismissSheet
}

/// Recipe detail: stats, "Al planning", "A la compra", ingredients and sub-recipes, notes that save
/// themselves, and steps.
@MainActor
@Observable
final class RecipeDetailViewModel: MVIViewModel {
    /// The use cases the detail depends on.
    struct UseCases {
        let observeDetail: any ObserveRecipeDetailUseCase
        let observeStats: any ObserveRecipeStatsUseCase
        let setFavorite: any SetRecipeFavoriteUseCase
        let updateNotes: any UpdateRecipeNotesUseCase
        let addRecipeToShoppingList: any AddRecipeToShoppingListUseCase
    }

    // MARK: - Properties

    let recipeID: UUID
    private(set) var state = RecipeDetailState.loading
    private(set) var notesState = RecipeNotesState.saved
    private(set) var detail: RecipeDetail?
    private(set) var stats = RecipeStats.never
    private(set) var notes = ""
    var presentedSheet: RecipeDetailSheet?
    var toast: Toast?

    @ObservationIgnored private let useCases: UseCases
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var observations: [Task<Void, Never>]?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var lastSavedNotes = ""
    @ObservationIgnored private var isNotesFocused = false

    // MARK: - Lifecycle

    init(
        recipeID: UUID,
        useCases: UseCases,
        debounce: Duration = .seconds(1),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.recipeID = recipeID
        self.useCases = useCases
        self.debounce = debounce
        self.sleep = sleep
        self.clock = clock
    }

    deinit {
        observations?.forEach { $0.cancel() }
        debounceTask?.cancel()
    }

    // MARK: - Derived

    var today: LocalDay { LocalDay.today(now: clock()) }

    // MARK: - Intents

    func send(_ intent: RecipeDetailIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        case .notesChanged(let text):
            notesChanged(text)
        case .notesFocusChanged(let isFocused):
            isNotesFocused = isFocused
            if !isFocused {
                debounceTask?.cancel()
                debounceTask = nil
                await saveNotes()
            }
        case .toggleFavorite:
            await toggleFavorite()
        case .addToShopping:
            await addToShopping()
        case .planMeal:
            let slot = detail?.recipe.mealTypes.first ?? .dinner
            presentedSheet = .planMeal(.new(day: today, slot: slot, recipeID: recipeID))
        case .edit:
            presentedSheet = .edit
        case .dismissSheet:
            presentedSheet = nil
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observations == nil else { return }
        let details = useCases.observeDetail.execute(recipeID: recipeID)
        let stats = useCases.observeStats.execute(recipeID: recipeID)
        observations = [
            Task { [weak self] in
                for await detail in details {
                    self?.apply(detail)
                }
            },
            Task { [weak self] in
                for await value in stats { self?.stats = value }
            },
        ]
    }

    private func apply(_ detail: RecipeDetail?) {
        self.detail = detail
        guard let detail else {
            state = .missing
            return
        }
        state = .loaded
        // Never overwrite what the user is typing; take remote changes only when nothing is pending.
        if notesState == .saved, !isNotesFocused {
            notes = detail.recipe.notes ?? ""
            lastSavedNotes = notes
        }
    }

    private func notesChanged(_ text: String) {
        guard text != notes else { return }
        notes = text
        notesState = .editing
        debounceTask?.cancel()
        let sleep = sleep
        let debounce = debounce
        debounceTask = Task { [weak self] in
            do {
                try await sleep(debounce)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.saveNotes()
        }
    }

    private func saveNotes() async {
        let text = notes
        guard text != lastSavedNotes else {
            if notesState != .saving { notesState = .saved }
            return
        }
        notesState = .saving
        do {
            try await useCases.updateNotes.execute(recipeID: recipeID, notes: text)
            lastSavedNotes = text
        } catch {
            toast = .error(error)
        }
        notesState = notes == lastSavedNotes ? .saved : .editing
    }

    private func toggleFavorite() async {
        guard let recipe = detail?.recipe else { return }
        do {
            try await useCases.setFavorite.execute(recipeID: recipeID, isFavorite: !recipe.isFavorite)
        } catch {
            toast = .error(error)
        }
    }

    private func addToShopping() async {
        do {
            try await useCases.addRecipeToShoppingList.execute(
                recipeID: recipeID,
                servings: nil,
                source: .manual,
                mealPlanEntryID: nil
            )
            toast = Toast(messageKey: "recipe.toast.added-to-shopping")
        } catch {
            toast = .error(error)
        }
    }
}
