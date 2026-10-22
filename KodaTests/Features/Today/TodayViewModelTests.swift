import Foundation
import Testing

@testable import Koda

@MainActor
@Suite("Today")
struct TodayViewModelTests {
    private func makeViewModel(_ environment: FeatureEnvironment, now: @escaping @Sendable () -> Date) -> TodayViewModel
    {
        TodayViewModel(
            useCases: TodayViewModel.UseCases(
                observeHousehold: environment.observeHousehold,
                observeTodayMeals: ObserveTodayMealsUseCaseImpl(planningRepository: environment.planning),
                observeFrozenItems: environment.observeFrozenItems,
                observeShoppingList: environment.observeShoppingList,
                observePendingDrafts: ObservePendingDraftsUseCaseImpl(repository: environment.planning),
                observeRecipeCatalog: environment.observeCatalog,
                skipMeal: SkipMealUseCaseImpl(repository: environment.planning, clock: now),
                resolveFrozenItem: ResolveFrozenItemUseCaseImpl(repository: environment.shopping, clock: now)
            ),
            clock: now
        )
    }

    @Test("Progress, next meal and the shopping summary come from the local database")
    func overview() async throws {
        let environment = try await FeatureEnvironment.make()
        let breakfast = try await environment.recipe("Galletas", mealTypes: [.breakfast])
        let dinner = try await environment.recipe("Ensalada César")
        try await environment.planMeal.execute(
            NewMealPlanEntry(day: TestClock.thursday, slot: .breakfast, recipeID: breakfast.id)
        )
        try await environment.planMeal.execute(
            NewMealPlanEntry(day: TestClock.thursday, slot: .dinner, recipeID: dinner.id)
        )
        try await environment.planMeal.execute(
            NewMealPlanEntry(day: TestClock.thursday, slot: .lunch, freeText: "Fuera")
        )
        try await environment.shopping.addEntry(NewShoppingEntry(item: .text("Leche")))

        let viewModel = makeViewModel(environment) { TestClock.now }
        await viewModel.send(.appeared)
        #expect(
            await eventually { viewModel.state == .ready && viewModel.meals.count == 3 && viewModel.shopping != nil }
        )
        #expect(viewModel.household?.displayName == "Test")
        #expect(viewModel.progress.doneCount == 1)
        #expect(viewModel.progress.totalCount == 2)
        #expect(viewModel.progress.nextMeal?.entry.recipeID == dinner.id)
        #expect(viewModel.shopping?.pendingProductCount == 1)
    }

    @Test("No lo comimos skips the meal and removes its consumption")
    func skip() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Curry")
        let entry = try await environment.planMeal.execute(
            NewMealPlanEntry(day: TestClock.thursday, slot: .lunch, recipeID: recipe.id)
        )
        try await environment.planning.logConsumption(
            NewConsumption(recipeID: recipe.id, day: TestClock.thursday, mealPlanEntryID: entry.id, source: .auto)
        )
        let viewModel = makeViewModel(environment) { TestClock.now }
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.meals.first?.isConsumed == true })

        await viewModel.send(.skipMeal(try #require(viewModel.meals.first)))
        #expect(await eventually { viewModel.meals.first?.isSkipped == true })
        #expect(viewModel.meals.first?.isConsumed == false)
        #expect(viewModel.progress.totalCount == 0)
        #expect(
            try await TestDatabase.count("consumptions", in: environment.database, where: "deleted_at IS NULL") == 0
        )
        #expect(viewModel.toast?.messageKey == "today.toast.skipped")
    }

    @Test("A frozen item appears from its reminder time until Hecho resolves it")
    func defrost() async throws {
        let environment = try await FeatureEnvironment.make()
        try await environment.database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO frozen_items (id, household_id, product_id, defrost_remind_at)
                    VALUES (?, ?, ?, '2026-10-22T14:00:00Z')
                    """,
                arguments: [ServerRows.uuid(7), TestDatabase.householdID, ServerRows.uuid(8)]
            )
        }
        let clock = MutableClock(TestClock.now)
        let viewModel = makeViewModel(environment) { clock.now }
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.frozenItems.count == 1 })
        #expect(viewModel.dueFrozenItems.isEmpty)

        clock.now = TestClock.now.addingTimeInterval(2 * 3600)
        await viewModel.send(.tick)
        #expect(viewModel.dueFrozenItems.count == 1)

        await viewModel.send(.resolveFrozenItem(try #require(viewModel.dueFrozenItems.first)))
        #expect(await eventually { viewModel.frozenItems.isEmpty })
    }

    @Test("Cambiar, the suggestion and the avatar open their sheets")
    func sheets() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Gnocchi")
        try await environment.planning.logConsumption(
            NewConsumption(recipeID: recipe.id, day: TestClock.thursday.adding(days: -21))
        )
        let viewModel = makeViewModel(environment) { TestClock.now }
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.suggestion?.recipe.id == recipe.id })

        await viewModel.send(.planSuggestion(recipe.id))
        #expect(
            viewModel.presentedSheet == .planMeal(.new(day: TestClock.thursday, slot: .dinner, recipeID: recipe.id))
        )
        await viewModel.send(.openProfile)
        #expect(viewModel.presentedSheet == .profile)
        await viewModel.send(.dismissSheet)
        #expect(viewModel.presentedSheet == nil)
    }
}

/// A clock tests can move forward.
// Guarded by `lock`; only tests use it.
// swiftlint:disable:next no_unchecked_sendable
final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    var now: Date {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}
