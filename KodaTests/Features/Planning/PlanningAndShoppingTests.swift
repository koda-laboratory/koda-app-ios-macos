import Foundation
import Testing

@testable import Koda

@Suite("Planning and Today observations")
struct PlanningTests {
    @Test("The week plan groups meals Monday to Sunday and Today reflects consumptions")
    func weekAndToday() async throws {
        let database = try await TestDatabase.make()
        let writer = LocalMutationWriter()
        let recipes = RecipeRepositoryImpl(database: database, writer: writer)
        let planning = PlanningRepositoryImpl(
            database: database,
            writer: writer,
            remoteDataSource: PlanningRemoteDataSourceImpl(
                httpService: TestHTTPStack(session: nil) { _ in (500, Data()) }.httpService,
                headerProvider: StaticHeaderProvider()
            )
        )
        let thursday = try #require(LocalDay("2026-10-22"))
        let recipe = try await recipes.saveRecipe(RecipeInput(name: "Lentejas"))
        let planMeal = PlanMealUseCaseImpl(repository: planning)
        let dinner = try await planMeal.execute(NewMealPlanEntry(day: thursday, slot: .dinner, recipeID: recipe.id))
        try await planMeal.execute(NewMealPlanEntry(day: thursday, slot: .lunch, freeText: "  Sobras  "))
        try await planMeal.execute(
            NewMealPlanEntry(day: thursday.adding(days: 7), slot: .lunch, freeText: "Otra semana")
        )
        await #expect(throws: KodaError.self) {
            try await planMeal.execute(NewMealPlanEntry(day: thursday, slot: .snack, freeText: " "))
        }

        var weeks = ObserveWeekPlanUseCaseImpl(repository: planning).execute(containing: thursday).makeAsyncIterator()
        let week = try #require(await weeks.next())
        #expect(week.startDay.description == "2026-10-19")
        #expect(week.days.count == 7)
        #expect(week.days[3].meals.map(\.title) == ["Sobras", "Lentejas"])
        #expect(week.days.flatMap(\.meals).count == 2)

        var today = ObserveTodayMealsUseCaseImpl(planningRepository: planning).execute(day: thursday)
            .makeAsyncIterator()
        #expect(await today.next()?.pendingCount == 2)

        try await LogConsumptionUseCaseImpl(repository: planning).execute(
            NewConsumption(recipeID: recipe.id, day: thursday, slot: .dinner, servings: 2, mealPlanEntryID: dinner.id)
        )
        let afterLog = try #require(await today.next())
        #expect(afterLog.pendingCount == 1)
        #expect(afterLog.meals(in: .dinner).first?.isConsumed == true)
        #expect(
            try await TestDatabase.string("SELECT logged_by FROM consumptions", in: database) == TestDatabase.userID
        )
    }

    @Test("Draft entries stay out of the planning and show up as pending drafts")
    func draftsAreSeparate() async throws {
        let database = try await TestDatabase.make()
        let draftID = ServerRows.uuid(50)
        try await database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO meal_plan_drafts (id, household_id, from_date, to_date, status, source, server_seq)
                    VALUES (?, ?, '2026-10-19', '2026-10-25', 'pending', 'mcp', 1)
                    """,
                arguments: [draftID, TestDatabase.householdID]
            )
            try db.execute(
                sql: """
                    INSERT INTO meal_plan_entries (id, household_id, date, slot, free_text, draft_id, server_seq)
                    VALUES (?, ?, '2026-10-20', 'lunch', 'Propuesta', ?, 2)
                    """,
                arguments: [ServerRows.uuid(51), TestDatabase.householdID, draftID]
            )
        }
        let planning = PlanningRepositoryImpl(
            database: database,
            writer: LocalMutationWriter(),
            remoteDataSource: PlanningRemoteDataSourceImpl(
                httpService: TestHTTPStack(session: nil) { _ in (500, Data()) }.httpService,
                headerProvider: StaticHeaderProvider()
            )
        )
        let monday = try #require(LocalDay("2026-10-19"))

        var drafts = ObservePendingDraftsUseCaseImpl(repository: planning).execute().makeAsyncIterator()
        let pending = try #require(await drafts.next())
        #expect(pending.count == 1)
        #expect(pending.first?.source == .mcp)
        #expect(pending.first?.entries.map(\.title) == ["Propuesta"])

        var entries = planning.observeEntries(from: monday, through: monday.adding(days: 6)).makeAsyncIterator()
        #expect(await entries.next()?.isEmpty == true)
    }

    @Test("Accepting a draft calls the API and then syncs")
    func acceptDraft() async throws {
        let stack = TestHTTPStack(session: TestHTTPStack.session(expiresAt: .now.addingTimeInterval(3600))) { _ in
            (200, TestJSON.data(["draft_id": ServerRows.uuid(50), "entries": 3]))
        }
        let planning = PlanningRepositoryImpl(
            database: try await TestDatabase.make(),
            writer: LocalMutationWriter(),
            remoteDataSource: PlanningRemoteDataSourceImpl(
                httpService: stack.httpService,
                headerProvider: stack.headerProvider
            )
        )
        let scheduler = RecordingSyncScheduler()
        let draftID = try #require(UUID(uuidString: ServerRows.uuid(50)))

        let entries = try await AcceptDraftUseCaseImpl(repository: planning, syncScheduler: scheduler).execute(
            draftID: draftID
        )

        #expect(entries == 3)
        #expect(
            stack.transport.requests.first?.path.hasSuffix("/functions/v1/api/drafts/\(ServerRows.uuid(50))/accept")
                == true
        )
        #expect(await scheduler.syncTriggers == [.manual])
    }
}

@Suite("Shopping list")
struct ShoppingListTests {
    @Test("Groups by category, recipes and text with pending entries first; clearing removes checked ones")
    func groupingAndClearing() async throws {
        let database = try await TestDatabase.make()
        let writer = LocalMutationWriter()
        let products = ProductRepositoryImpl(database: database, writer: writer)
        let shopping = ShoppingRepositoryImpl(database: database, writer: writer)
        let milk = try await products.saveProduct(ProductInput(name: "Leche", category: .basics))
        let bleach = try await products.saveProduct(ProductInput(name: "Lejía", category: .cleaning))
        let add = AddShoppingEntryUseCaseImpl(repository: shopping)
        let milkEntry = try await add.execute(NewShoppingEntry(item: .product(milk.id), quantity: 2, unit: "l"))
        try await add.execute(NewShoppingEntry(item: .product(bleach.id)))
        try await add.execute(NewShoppingEntry(item: .text("Velas")))
        let bread = try await add.execute(NewShoppingEntry(item: .text("Pan")))
        try await SetShoppingEntryCheckedUseCaseImpl(repository: shopping).execute(entryID: bread.id, isChecked: true)
        #expect(milkEntry.title == "Leche")
        #expect(milkEntry.category == .basics)

        var lists = ObserveShoppingListUseCaseImpl(repository: shopping).execute().makeAsyncIterator()
        let list = try #require(await lists.next())
        #expect(list.sections.map(\.group) == [.category(.basics), .category(.cleaning), .other])
        #expect(list.sections.last?.entries.map(\.title) == ["Velas", "Pan"])
        #expect(list.pendingCount == 3)
        #expect(list.checkedCount == 1)

        let removed = try await ClearCheckedShoppingEntriesUseCaseImpl(repository: shopping).execute()
        #expect(removed == 1)
        #expect(try await TestDatabase.count("shopping_entries", in: database, where: "deleted_at IS NULL") == 3)
        #expect(try await TestDatabase.count("outbox", in: database, where: "op = 'delete'") == 1)

        await #expect(throws: KodaError.self) {
            try await add.execute(NewShoppingEntry(item: .text("   ")))
        }
    }
}
