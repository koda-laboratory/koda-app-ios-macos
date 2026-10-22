import Foundation
import Testing

@testable import Koda

/// A sleep that only returns when the test releases it.
actor ManualSleeper {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var sleepCount = 0

    func sleep() async {
        sleepCount += 1
        await withCheckedContinuation { waiters.append($0) }
    }

    func releaseAll() {
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

/// Records notes saves.
actor RecordingNotesUseCase: UpdateRecipeNotesUseCase {
    private(set) var saved: [String] = []
    private let inner: any UpdateRecipeNotesUseCase

    init(inner: any UpdateRecipeNotesUseCase) {
        self.inner = inner
    }

    func execute(recipeID: UUID, notes: String) async throws(KodaError) {
        saved.append(notes)
        try await inner.execute(recipeID: recipeID, notes: notes)
    }
}

@MainActor
@Suite("Recipe detail")
struct RecipeDetailViewModelTests {
    private func makeViewModel(
        _ environment: FeatureEnvironment,
        recipeID: UUID,
        notes: RecordingNotesUseCase,
        sleeper: ManualSleeper
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            recipeID: recipeID,
            useCases: RecipeDetailViewModel.UseCases(
                observeDetail: ObserveRecipeDetailUseCaseImpl(repository: environment.recipes),
                observeStats: ObserveRecipeStatsUseCaseImpl(repository: environment.recipes),
                setFavorite: SetRecipeFavoriteUseCaseImpl(repository: environment.recipes),
                updateNotes: notes,
                addRecipeToShoppingList: environment.addRecipeToShopping,
                logConsumption: LogConsumptionUseCaseImpl(repository: environment.planning)
            ),
            sleep: { _ in await sleeper.sleep() },
            clock: { TestClock.now }
        )
    }

    @Test("Typing debounces: several keystrokes produce one save after the quiet period")
    func debounce() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Arroz a la cubana")
        let notes = RecordingNotesUseCase(inner: UpdateRecipeNotesUseCaseImpl(repository: environment.recipes))
        let sleeper = ManualSleeper()
        let viewModel = makeViewModel(environment, recipeID: recipe.id, notes: notes, sleeper: sleeper)
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.state == .loaded })

        await viewModel.send(.notesFocusChanged(true))
        await viewModel.send(.notesChanged("C"))
        await viewModel.send(.notesChanged("Co"))
        await viewModel.send(.notesChanged("Con caldo"))
        #expect(viewModel.notesState == .editing)
        #expect(await notes.saved.isEmpty)

        #expect(await waitUntil { await sleeper.sleepCount == 3 })
        await sleeper.releaseAll()
        #expect(await eventually { viewModel.notesState == .saved })
        #expect(await notes.saved == ["Con caldo"])
        #expect(
            try await TestDatabase.string("SELECT notes FROM recipes", in: environment.database) == "Con caldo"
        )
    }

    @Test("Losing focus saves right away, without waiting for the debounce")
    func focusLoss() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Gazpacho")
        let notes = RecordingNotesUseCase(inner: UpdateRecipeNotesUseCaseImpl(repository: environment.recipes))
        let sleeper = ManualSleeper()
        let viewModel = makeViewModel(environment, recipeID: recipe.id, notes: notes, sleeper: sleeper)
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.state == .loaded })

        await viewModel.send(.notesFocusChanged(true))
        await viewModel.send(.notesChanged("Mejor frío"))
        await viewModel.send(.notesFocusChanged(false))
        #expect(viewModel.notesState == .saved)
        #expect(await notes.saved == ["Mejor frío"])

        // The cancelled debounce never saves again.
        await sleeper.releaseAll()
        try await Task.sleep(for: .milliseconds(50))
        #expect(await notes.saved == ["Mejor frío"])
    }

    @Test("Remote changes refresh the notes only while nothing is being edited")
    func remoteChanges() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Ramen")
        let notes = RecordingNotesUseCase(inner: UpdateRecipeNotesUseCaseImpl(repository: environment.recipes))
        let viewModel = makeViewModel(environment, recipeID: recipe.id, notes: notes, sleeper: ManualSleeper())
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.state == .loaded })

        try await environment.recipes.updateNotes(recipeID: recipe.id, notes: "Desde el otro iPhone")
        #expect(await eventually { viewModel.notes == "Desde el otro iPhone" })

        await viewModel.send(.notesFocusChanged(true))
        await viewModel.send(.notesChanged("Lo mío"))
        try await environment.recipes.updateNotes(recipeID: recipe.id, notes: "Otra vez remoto")
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.notes == "Lo mío")
    }

    @Test("La comimos logs a manual consumption; A la compra adds the recipe entry")
    func actions() async throws {
        let environment = try await FeatureEnvironment.make()
        let rice = try await environment.product("Arroz")
        let recipe = try await environment.recipe("Arroz a la cubana", products: [rice])
        let notes = RecordingNotesUseCase(inner: UpdateRecipeNotesUseCaseImpl(repository: environment.recipes))
        let viewModel = makeViewModel(environment, recipeID: recipe.id, notes: notes, sleeper: ManualSleeper())
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.state == .loaded })

        await viewModel.send(.logConsumption)
        #expect(try await TestDatabase.string("SELECT source FROM consumptions", in: environment.database) == "manual")
        #expect(await eventually { viewModel.stats.timesEaten == 1 })

        await viewModel.send(.addToShopping)
        #expect(try await TestDatabase.count("shopping_entries", in: environment.database) == 1)
        #expect(viewModel.toast?.messageKey == "recipe.toast.added-to-shopping")

        await viewModel.send(.planMeal)
        #expect(
            viewModel.presentedSheet == .planMeal(.new(day: TestClock.thursday, slot: .dinner, recipeID: recipe.id))
        )
    }
}
