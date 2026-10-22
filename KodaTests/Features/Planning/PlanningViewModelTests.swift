import Foundation
import Testing

@testable import Koda

@MainActor
@Suite("Planning screens")
struct PlanningViewModelTests {
    private func makePlanning(_ environment: FeatureEnvironment) -> PlanningViewModel {
        PlanningViewModel(
            useCases: PlanningViewModel.UseCases(
                observeWeekPlan: ObserveWeekPlanUseCaseImpl(repository: environment.planning),
                observePendingDrafts: ObservePendingDraftsUseCaseImpl(repository: environment.planning),
                observeHousehold: environment.observeHousehold,
                updatePlannedMeal: UpdatePlannedMealUseCaseImpl(repository: environment.planning),
                removePlannedMeal: RemovePlannedMealUseCaseImpl(repository: environment.planning),
                discardDraft: DiscardDraftUseCaseImpl(
                    repository: environment.planning,
                    syncScheduler: environment.syncScheduler
                )
            ),
            clock: { TestClock.now }
        )
    }

    private func makePlanMeal(_ environment: FeatureEnvironment, request: PlanMealRequest) -> PlanMealViewModel {
        PlanMealViewModel(
            request: request,
            planMeal: environment.planMeal,
            updatePlannedMeal: UpdatePlannedMealUseCaseImpl(repository: environment.planning),
            removePlannedMeal: RemovePlannedMealUseCaseImpl(repository: environment.planning),
            observeRecipeCatalog: environment.observeCatalog,
            observeHousehold: environment.observeHousehold
        )
    }

    @Test("The week navigates and meals move between days and slots")
    func weekAndMove() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Ramen")
        let entry = try await environment.planMeal.execute(
            NewMealPlanEntry(day: TestClock.thursday, slot: .lunch, recipeID: recipe.id)
        )
        let viewModel = makePlanning(environment)
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.week?.days.flatMap(\.meals).count == 1 })
        #expect(viewModel.weekStart.description == "2026-10-19")
        #expect(viewModel.selectedDay == TestClock.thursday)
        #expect(viewModel.shoppingCycle.from.description == "2026-10-24")

        await viewModel.send(.moveMeal(entryID: entry.id, day: TestClock.thursday.adding(days: 1), slot: .dinner))
        #expect(await eventually { viewModel.week?.days[4].meals(in: .dinner).first?.id == entry.id })

        await viewModel.send(.nextWeek)
        #expect(viewModel.weekStart.description == "2026-10-26")
        #expect(await eventually { viewModel.week?.startDay.description == "2026-10-26" })
        #expect(viewModel.week?.days.flatMap(\.meals).isEmpty == true)
        await viewModel.send(.goToToday)
        #expect(viewModel.weekStart.description == "2026-10-19")
    }

    @Test("Adding, editing and generating present their sheets; removing tombstones the meal")
    func sheetsAndRemove() async throws {
        let environment = try await FeatureEnvironment.make()
        let entry = try await environment.planMeal.execute(
            NewMealPlanEntry(day: TestClock.thursday, slot: .dinner, freeText: "Fuera")
        )
        let viewModel = makePlanning(environment)
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.state == .ready })
        await viewModel.send(.addMeal(TestClock.thursday, .lunch))
        #expect(viewModel.presentedSheet == .planMeal(.new(day: TestClock.thursday, slot: .lunch, recipeID: nil)))
        await viewModel.send(.generateShopping)
        #expect(viewModel.presentedSheet == .generateShopping)
        await viewModel.send(.removeMeal(entry))
        #expect(await eventually { viewModel.week?.days.flatMap(\.meals).isEmpty == true })
    }

    @Test("Plan meal validates, then saves a recipe meal with its own time")
    func planMeal() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Paella", mealTypes: [.lunch])
        let viewModel = makePlanMeal(environment, request: .new(day: TestClock.thursday, slot: .lunch, recipeID: nil))
        await viewModel.send(.appeared)
        await viewModel.send(.save)
        #expect(viewModel.state == .invalidForm)
        #expect(viewModel.showsRecipeError)

        #expect(await eventually { viewModel.filteredRecipes.count == 1 })
        await viewModel.send(.selectRecipe(recipe.id))
        viewModel.form.usesCustomTime = true
        viewModel.form.time = LocalTime(hour: 13, minute: 0)
        await viewModel.send(.save)
        #expect(viewModel.state == .completed)
        let entries = try await environment.planning.entries(from: TestClock.thursday, through: TestClock.thursday)
        #expect(entries.first?.recipeID == recipe.id)
        #expect(entries.first?.scheduledTime == LocalTime(hour: 13, minute: 0))
    }

    @Test("Changing a meal updates it and can turn it into free text; deleting removes it")
    func editMeal() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Curry")
        let entry = try await environment.planMeal.execute(
            NewMealPlanEntry(day: TestClock.thursday, slot: .dinner, recipeID: recipe.id)
        )
        let viewModel = makePlanMeal(environment, request: .edit(entry))
        #expect(viewModel.isEditing)
        viewModel.form.kind = .text
        viewModel.form.freeText = "  Sobras  "
        await viewModel.send(.save)
        #expect(viewModel.state == .completed)
        var entries = try await environment.planning.entries(from: TestClock.thursday, through: TestClock.thursday)
        #expect(entries.first?.title == "Sobras")
        #expect(entries.first?.recipeID == nil)

        let delete = makePlanMeal(environment, request: .edit(try #require(entries.first)))
        await delete.send(.delete)
        entries = try await environment.planning.entries(from: TestClock.thursday, through: TestClock.thursday)
        #expect(entries.isEmpty)
    }

    @Test("Draft review finishes when the draft is no longer pending")
    func draftReview() async throws {
        let environment = try await FeatureEnvironment.make()
        let draftID = ServerRows.uuid(70)
        try await environment.database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO meal_plan_drafts (id, household_id, from_date, to_date, status, source)
                    VALUES (?, ?, '2026-10-26', '2026-11-01', 'pending', 'mcp')
                    """,
                arguments: [draftID, TestDatabase.householdID]
            )
            try db.execute(
                sql: """
                    INSERT INTO meal_plan_entries (id, household_id, date, slot, free_text, position, draft_id)
                    VALUES (?, ?, '2026-10-26', 'lunch', 'Lentejas', 0, ?)
                    """,
                arguments: [ServerRows.uuid(71), TestDatabase.householdID, draftID]
            )
        }
        let viewModel = DraftReviewViewModel(
            draftID: try #require(UUID(uuidString: draftID)),
            observePendingDrafts: ObservePendingDraftsUseCaseImpl(repository: environment.planning),
            acceptDraft: AcceptDraftUseCaseImpl(
                repository: environment.planning,
                syncScheduler: environment.syncScheduler
            ),
            discardDraft: DiscardDraftUseCaseImpl(
                repository: environment.planning,
                syncScheduler: environment.syncScheduler
            )
        )
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.state == .ready })
        #expect(viewModel.days.first?.meals.first?.title == "Lentejas")
        await viewModel.send(.accept)
        #expect(viewModel.state == .finished)
        #expect(await environment.syncScheduler.syncTriggers == [.manual])
    }
}
