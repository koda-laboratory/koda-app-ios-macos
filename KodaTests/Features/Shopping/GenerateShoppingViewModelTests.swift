import Foundation
import Testing

@testable import Koda

@MainActor
@Suite("Generate shopping")
struct GenerateShoppingViewModelTests {
    /// Thursday 22: the Friday cycle covers Saturday 24 → Friday 30.
    private func makeViewModel(_ environment: FeatureEnvironment) -> GenerateShoppingViewModel {
        GenerateShoppingViewModel(
            loadCandidates: environment.loadCandidates,
            addRecipeToShoppingList: environment.addRecipeToShopping,
            observeHousehold: environment.observeHousehold,
            clock: { TestClock.now }
        )
    }

    @Test("Proposes the cycle, lists planned recipes, skips free text and marks the ones already added")
    func candidates() async throws {
        let environment = try await FeatureEnvironment.make()
        let rice = try await environment.product("Arroz")
        let paella = try await environment.recipe("Paella", products: [rice])
        let curry = try await environment.recipe("Curry", products: [rice])
        let saturday = TestClock.thursday.adding(days: 2)
        let first = try await environment.planMeal.execute(
            NewMealPlanEntry(day: saturday, slot: .lunch, recipeID: paella.id)
        )
        let second = try await environment.planMeal.execute(
            NewMealPlanEntry(day: saturday.adding(days: 3), slot: .dinner, recipeID: curry.id)
        )
        try await environment.planMeal.execute(
            NewMealPlanEntry(day: saturday, slot: .dinner, freeText: "Comemos fuera")
        )
        try await environment.planMeal.execute(
            NewMealPlanEntry(day: TestClock.thursday, slot: .lunch, recipeID: curry.id)
        )
        try await environment.addRecipeToShopping.execute(
            recipeID: curry.id,
            servings: nil,
            source: .plan,
            mealPlanEntryID: second.id
        )

        let viewModel = makeViewModel(environment)
        await viewModel.send(.appeared)

        #expect(viewModel.from.description == "2026-10-24")
        #expect(viewModel.through.description == "2026-10-30")
        #expect(viewModel.candidates.map(\.id) == [first.id, second.id])
        #expect(viewModel.candidates.map(\.isAlreadyOnList) == [false, true])
        #expect(viewModel.candidates.first?.productCount == 1)
        #expect(viewModel.toAdd.map(\.id) == [first.id])
    }

    @Test("Adds only the selected meals, each linked to its planned meal, and never twice")
    func addSelected() async throws {
        let environment = try await FeatureEnvironment.make()
        let rice = try await environment.product("Arroz")
        let paella = try await environment.recipe("Paella", products: [rice])
        let burrito = try await environment.recipe("Burrito", products: [rice])
        let saturday = TestClock.thursday.adding(days: 2)
        let first = try await environment.planMeal.execute(
            NewMealPlanEntry(day: saturday, slot: .lunch, recipeID: paella.id)
        )
        let second = try await environment.planMeal.execute(
            NewMealPlanEntry(day: saturday, slot: .dinner, recipeID: burrito.id)
        )

        let viewModel = makeViewModel(environment)
        await viewModel.send(.appeared)
        await viewModel.send(.toggle(second.id))
        #expect(viewModel.toAdd.map(\.id) == [first.id])
        await viewModel.send(.add)
        #expect(viewModel.state == .completed(added: 1))

        let list = try #require(await firstValue(environment.observeShoppingList.execute()))
        #expect(list.entries.map(\.mealPlanEntryID) == [first.id])

        // A second generation only adds what is new, and the repository refuses duplicates per planned meal.
        let again = makeViewModel(environment)
        await again.send(.appeared)
        #expect(again.toAdd.map(\.id) == [second.id])
        await again.send(.toggle(first.id))
        #expect(again.toAdd.map(\.id) == [second.id])
        try await environment.addRecipeToShopping.execute(
            recipeID: paella.id,
            servings: nil,
            source: .plan,
            mealPlanEntryID: first.id
        )
        let entries = try #require(await firstValue(environment.observeShoppingList.execute())).entries
        #expect(entries.filter { $0.mealPlanEntryID == first.id }.count == 1)
    }

    @Test("Quick ranges and manual dates reload the candidates")
    func ranges() async throws {
        let environment = try await FeatureEnvironment.make()
        let paella = try await environment.recipe("Paella")
        let today = try await environment.planMeal.execute(
            NewMealPlanEntry(day: TestClock.thursday, slot: .dinner, recipeID: paella.id)
        )
        let viewModel = makeViewModel(environment)
        await viewModel.send(.appeared)
        #expect(viewModel.candidates.isEmpty)

        await viewModel.send(.selectQuickRange(.fromToday))
        #expect(viewModel.quickRange == .fromToday)
        #expect(viewModel.candidates.map(\.id) == [today.id])

        await viewModel.send(.setThrough(TestClock.thursday.adding(days: -1)))
        #expect(viewModel.quickRange == nil)
        #expect(viewModel.from == viewModel.through)
        #expect(viewModel.candidates.isEmpty)
    }
}
