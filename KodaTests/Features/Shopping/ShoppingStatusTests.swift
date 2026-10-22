import Foundation
import GRDB
import Testing

@testable import Koda

@Suite("Three-state shopping list")
struct ShoppingStatusTests {
    @Test(
        "Tap toggles have, the snowflake toggles frozen",
        arguments: [
            (ShoppingItemStatus.pending, ShoppingItemStatus.have, ShoppingItemStatus.frozen),
            (.have, .pending, .frozen),
            (.frozen, .have, .pending),
        ]
    )
    func transitions(from: ShoppingItemStatus, tap: ShoppingItemStatus, snowflake: ShoppingItemStatus) {
        #expect(from.togglingHave == tap)
        #expect(from.togglingFrozen == snowflake)
    }

    @Test("A status change writes status, checked and checked_at together in the outbox")
    func entryStatusMutation() async throws {
        let environment = try await FeatureEnvironment.make()
        let milk = try await environment.product("Leche")
        let entry = try await environment.shopping.addEntry(NewShoppingEntry(item: .product(milk.id)))

        try await environment.shopping.setEntryStatus(id: entry.id, status: .frozen)
        let frozenFields = TestDatabase.fields(of: try #require(try await environment.outbox().last))
        #expect(frozenFields["status"] as? String == "frozen")
        #expect(frozenFields["checked"] as? Bool == true)
        #expect(frozenFields["checked_at"] is String)

        try await environment.shopping.setEntryStatus(id: entry.id, status: .pending)
        let pendingFields = TestDatabase.fields(of: try #require(try await environment.outbox().last))
        #expect(pendingFields["status"] as? String == "pending")
        #expect(pendingFields["checked"] as? Bool == false)
    }

    @Test("A pending insert does not send the status group (the server keeps its default)")
    func pendingInsert() async throws {
        let environment = try await FeatureEnvironment.make()
        try await environment.shopping.addEntry(NewShoppingEntry(item: .text("Pilas")))
        let fields = TestDatabase.fields(of: try #require(try await environment.outbox().first))
        #expect(fields["status"] == nil)
        #expect(fields["checked"] == nil)
    }

    @Test("A recipe entry becomes have when every product is; a frozen product keeps it pending")
    func recipeItems() async throws {
        let environment = try await FeatureEnvironment.make()
        let rice = try await environment.product("Arroz")
        let eggs = try await environment.product("Huevos")
        let recipe = try await environment.recipe("Arroz a la cubana", products: [rice, eggs])
        let entry = try await environment.addRecipeToShopping.execute(
            recipeID: recipe.id,
            servings: nil,
            source: .manual,
            mealPlanEntryID: nil
        )
        let items = entry.items
        #expect(items.count == 2)

        try await environment.shopping.setItemStatus(id: items[0].id, status: .have)
        try await environment.shopping.setItemStatus(id: items[1].id, status: .frozen)
        var list = try #require(await firstValue(environment.observeShoppingList.execute()))
        #expect(list.entries.first?.status == .pending)
        #expect(list.pendingProductCount == 0)

        try await environment.shopping.setItemStatus(id: items[1].id, status: .have)
        list = try #require(await firstValue(environment.observeShoppingList.execute()))
        #expect(list.entries.first?.status == .have)
    }

    @Test("Vaciar removes only what we have; frozen products stay")
    func clearHave() async throws {
        let environment = try await FeatureEnvironment.make()
        let first = try await environment.shopping.addEntry(NewShoppingEntry(item: .text("Pan")))
        let second = try await environment.shopping.addEntry(NewShoppingEntry(item: .text("Alitas")))
        try await environment.shopping.addEntry(NewShoppingEntry(item: .text("Leche")))
        try await environment.shopping.setEntryStatus(id: first.id, status: .have)
        try await environment.shopping.setEntryStatus(id: second.id, status: .frozen)

        #expect(try await environment.shopping.removeCheckedEntries() == 1)
        let list = try #require(await firstValue(environment.observeShoppingList.execute()))
        #expect(list.entries.map(\.title).sorted() == ["Alitas", "Leche"])
    }

    @Test("Pulled rows from a backend without status derive it from checked")
    func pullCompatibility() async throws {
        let database = try await TestDatabase.make()
        let local = SyncLocalDataSourceImpl(database: database)
        let row = ServerRows.sync(ServerRows.uuid(1), seq: 1).merging([
            "kind": "text", "text": "Pan", "checked": true, "checked_at": "2026-10-22T10:00:00Z", "source": "manual",
            "position": 0,
        ]) { $1 }
        let page = try JSONDecoder.supabase().decode(
            SyncPullResponseDTO.self,
            from: ServerRows.pull(["shopping_entries": [row]], cursor: 1)
        )
        _ = try await local.apply(page, syncedAt: .now)
        #expect(try await TestDatabase.string("SELECT status FROM shopping_entries", in: database) == "have")
    }

    @Test("Resolving a frozen item writes only resolved_at locally and enqueues it")
    func resolveFrozenItem() async throws {
        let environment = try await FeatureEnvironment.make()
        let id = ServerRows.uuid(9)
        try await environment.database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO frozen_items (id, household_id, product_id, defrost_remind_at, server_seq)
                    VALUES (?, ?, ?, '2026-10-22T10:00:00Z', 3)
                    """,
                arguments: [id, TestDatabase.householdID, ServerRows.uuid(2)]
            )
        }
        var frozen = try #require(await firstValue(environment.observeFrozenItems.execute()))
        #expect(frozen.count == 1)
        #expect(frozen.first?.isDue(now: TestClock.now) == true)

        try await ResolveFrozenItemUseCaseImpl(repository: environment.shopping, clock: { TestClock.now })
            .execute(frozenItemID: try #require(UUID(uuidString: id)))
        frozen = try #require(await firstValue(environment.observeFrozenItems.execute()))
        #expect(frozen.isEmpty)
        let mutation = try #require(try await environment.outbox().last)
        #expect(mutation.tableName == "frozen_items")
        #expect(TestDatabase.fields(of: mutation)["resolved_at"] is String)
    }
}
