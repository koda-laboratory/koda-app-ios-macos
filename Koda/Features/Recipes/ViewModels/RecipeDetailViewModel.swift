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

/// Saving a picked photo (re-encoding, writing the file and the rows) takes a moment on large images.
enum RecipePhotoSaveState: Sendable, Equatable {
    case idle
    case saving
}

enum RecipeDetailSheet: Sendable, Equatable, Identifiable {
    case planMeal(PlanMealRequest)
    case edit
    /// "Añadir foto", with "Usar como portada" preselected when the recipe has no cover yet.
    case addPhoto(asCover: Bool)
    /// "Añadir vídeo".
    case addLink

    var id: String {
        switch self {
        case .planMeal(let request): "plan-\(request.id)"
        case .edit: "edit"
        case .addPhoto: "add-photo"
        case .addLink: "add-link"
        }
    }
}

/// The full-screen viewer, opened on one image of the gallery.
struct RecipePhotoViewerRequest: Sendable, Equatable, Identifiable {
    let initialPath: String

    var id: String { initialPath }
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
    case addPhotoTapped
    /// A picked, captured or dropped image.
    case addPhoto(Data, asCover: Bool)
    case setCover(RecipeGalleryItem)
    case deletePhoto(RecipeGalleryItem)
    case openPhoto(RecipeGalleryItem)
    case dismissViewer
    case addLinkTapped
    case removeLink(RecipeLink)
}

/// Recipe detail: stats, "Al planning", "A la compra", photos, video links, ingredients and sub-recipes, notes that
/// save themselves, and steps.
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
        let addPhoto: any AddRecipePhotoUseCase
        let setCover: any SetRecipeCoverUseCase
        let deletePhoto: any DeleteRecipePhotoUseCase
        let observeLinks: any ObserveRecipeLinksUseCase
        let removeLink: any RemoveRecipeLinkUseCase
    }

    // MARK: - Properties

    let recipeID: UUID
    private(set) var state = RecipeDetailState.loading
    private(set) var notesState = RecipeNotesState.saved
    private(set) var detail: RecipeDetail?
    private(set) var stats = RecipeStats.never
    private(set) var links: [RecipeLink] = []
    private(set) var notes = ""
    private(set) var photoSaveState = RecipePhotoSaveState.idle
    var presentedSheet: RecipeDetailSheet?
    var presentedViewer: RecipePhotoViewerRequest?
    var toast: Toast?
    private(set) var feedback: FeedbackEvent?

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
        case .addPhotoTapped:
            presentedSheet = .addPhoto(asCover: detail?.recipe.imagePath == nil)
        case .addPhoto(let data, let asCover):
            presentedSheet = nil
            await addPhoto(data, asCover: asCover)
        case .setCover(let item):
            await setCover(item)
        case .deletePhoto(let item):
            await deletePhoto(item)
        case .openPhoto(let item):
            presentedViewer = RecipePhotoViewerRequest(initialPath: item.path)
        case .dismissViewer:
            presentedViewer = nil
        case .addLinkTapped:
            presentedSheet = .addLink
        case .removeLink(let link):
            await removeLink(link)
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observations == nil else { return }
        let details = useCases.observeDetail.execute(recipeID: recipeID)
        let stats = useCases.observeStats.execute(recipeID: recipeID)
        let links = useCases.observeLinks.execute(recipeID: recipeID)
        observations = [
            Task { [weak self] in
                for await detail in details {
                    self?.apply(detail)
                }
            },
            Task { [weak self] in
                for await value in stats { self?.stats = value }
            },
            Task { [weak self] in
                for await value in links { self?.links = value }
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
            feedback = FeedbackEvent(recipe.isFavorite ? .removed : .added)
        } catch {
            toast = .error(error)
        }
    }

    private func addPhoto(_ data: Data, asCover: Bool) async {
        guard photoSaveState == .idle else { return }
        photoSaveState = .saving
        do {
            try await useCases.addPhoto.execute(recipeID: recipeID, imageData: data, asCover: asCover)
            feedback = FeedbackEvent(.added)
        } catch {
            toast = .error(error)
        }
        photoSaveState = .idle
    }

    private func setCover(_ item: RecipeGalleryItem) async {
        do {
            try await useCases.setCover.execute(recipeID: recipeID, item: item)
            toast = Toast(messageKey: "recipe.photos.toast.cover")
        } catch {
            toast = .error(error)
        }
    }

    private func deletePhoto(_ item: RecipeGalleryItem) async {
        do {
            try await useCases.deletePhoto.execute(recipeID: recipeID, item: item)
            feedback = FeedbackEvent(.removed)
            // The viewer closes when its last image goes.
            if detail?.gallery.count ?? 0 <= 1 { presentedViewer = nil }
        } catch {
            toast = .error(error)
        }
    }

    private func removeLink(_ link: RecipeLink) async {
        do {
            try await useCases.removeLink.execute(linkID: link.id)
            feedback = FeedbackEvent(.removed)
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
            feedback = FeedbackEvent(.added)
            toast = Toast(messageKey: "recipe.toast.added-to-shopping")
        } catch {
            toast = .error(error)
        }
    }
}
