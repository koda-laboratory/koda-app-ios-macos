import Foundation
import GRDB
import Testing

@testable import Koda

@Suite("Local write path (row + outbox in one transaction)")
struct LocalMutationWriterTests {
    private struct ExpectedFailure: Error {}

    private let fixedNow = Date(timeIntervalSince1970: 1_792_663_200)

    @Test("Saving a row enqueues exactly one upsert with client-writable fields")
    func saveEnqueuesUpsert() async throws {
        let database = try await TestDatabase.make()
        let writer = LocalMutationWriter(clock: { [fixedNow] in fixedNow })
        let repository = RecipeRepositoryImpl(database: database, writer: writer)

        let recipe = try await repository.saveRecipe(
            RecipeInput(name: "Pollo al horno", mealTypes: [.lunch], steps: ["Hornear"], isFavorite: true)
        )

        let outbox = try await TestDatabase.outbox(database)
        #expect(outbox.count == 1)
        let entry = try #require(outbox.first)
        #expect(entry.tableName == "recipes")
        #expect(entry.rowId == recipe.id.lowercasedString)
        #expect(entry.op == .upsert)
        #expect(entry.clientTs == "2026-10-22T10:00:00.000Z")

        let fields = TestDatabase.fields(of: entry)
        #expect(fields["household_id"] as? String == TestDatabase.householdID)
        #expect(fields["name"] as? String == "Pollo al horno")
        #expect(fields["meal_types"] as? [String] == ["lunch"])
        #expect(fields["steps"] as? [String] == ["Hornear"])
        #expect(fields["is_favorite"] as? Bool == true)
        for serverColumn in ["id", "created_at", "updated_at", "updated_by", "deleted_at", "server_seq"] {
            #expect(fields[serverColumn] == nil, "\(serverColumn) must not be sent")
        }

        let stored = try await database.writer.read { db in
            try RecipeRecord.fetchOne(db, key: recipe.id.lowercasedString)
        }
        #expect(stored?.householdId == TestDatabase.householdID)
        #expect(stored?.updatedBy == TestDatabase.userID)
        #expect(stored?.clientUpdatedAt == "2026-10-22T10:00:00.000Z")
        #expect(stored?.serverSeq == nil)
    }

    @Test("A failing transaction rolls back the row and its outbox entry together")
    func rollbackKeepsRowAndOutboxConsistent() async throws {
        let database = try await TestDatabase.make()
        let writer = LocalMutationWriter()

        await #expect(throws: (any Error).self) {
            try await database.writer.write { db in
                try writer.save(StoreRecord(id: LocalMutationWriter.newID(), householdId: "", name: "Aldi"), in: db)
                throw ExpectedFailure()
            }
        }

        #expect(try await TestDatabase.count("stores", in: database) == 0)
        #expect(try await TestDatabase.count("outbox", in: database) == 0)
    }

    @Test("Writes fail without a cached household")
    func requiresHousehold() async throws {
        let database = try await TestDatabase.make(signedIn: false)
        let repository = ProductRepositoryImpl(database: database, writer: LocalMutationWriter())

        await #expect(throws: KodaError.self) {
            try await repository.saveProduct(ProductInput(name: "Leche"))
        }
        #expect(try await TestDatabase.count("outbox", in: database) == 0)
    }

    @Test("Deleting tombstones the row, cascades locally and enqueues one delete")
    func deleteTombstonesAndCascades() async throws {
        let database = try await TestDatabase.make()
        let writer = LocalMutationWriter()
        let products = ProductRepositoryImpl(database: database, writer: writer)
        let recipes = RecipeRepositoryImpl(database: database, writer: writer)
        let product = try await products.saveProduct(ProductInput(name: "Pollo"))
        let recipe = try await recipes.saveRecipe(RecipeInput(name: "Pollo al horno"))
        try await recipes.addIngredient(
            RecipeIngredientInput(recipeID: recipe.id, productID: product.id, quantity: 500)
        )
        let outboxBefore = try await TestDatabase.count("outbox", in: database)

        try await recipes.deleteRecipe(id: recipe.id)

        #expect(try await TestDatabase.count("recipes", in: database, where: "deleted_at IS NOT NULL") == 1)
        #expect(try await TestDatabase.count("recipe_ingredients", in: database, where: "deleted_at IS NOT NULL") == 1)
        let outbox = try await TestDatabase.outbox(database)
        #expect(outbox.count == outboxBefore + 1)
        let delete = try #require(outbox.last)
        #expect(delete.op == .delete)
        #expect(delete.tableName == "recipes")
        #expect(delete.fieldsJson == nil)

        // Tombstoned rows disappear from observations and cannot be upserted again.
        var iterator = recipes.observeRecipes().makeAsyncIterator()
        #expect(await iterator.next()?.isEmpty == true)
        await #expect(throws: KodaError.self) {
            try await recipes.setFavorite(recipeID: recipe.id, isFavorite: true)
        }
    }

    @Test("Deleting an already deleted row is a no-op")
    func deleteIsIdempotent() async throws {
        let database = try await TestDatabase.make()
        let products = ProductRepositoryImpl(database: database, writer: LocalMutationWriter())
        let store = try await products.saveStore(StoreInput(name: "Mercadona"))
        try await products.deleteStore(id: store.id)
        try await products.deleteStore(id: store.id)
        #expect(try await TestDatabase.count("outbox", in: database, where: "op = 'delete'") == 1)
    }
}

@Suite("Shopping per-field last-writer-wins timestamps")
struct ShoppingTimestampTests {
    /// Advances one second per call so every write gets a distinct client timestamp.
    private final class TickingClock: Sendable {
        private let ticks = LateBound<Int>()

        func now() -> Date {
            let tick = (ticks.value ?? 0) + 1
            ticks.set(tick)
            return Date(timeIntervalSince1970: 1_792_663_200 + TimeInterval(tick))
        }
    }

    @Test("Insert sets name_updated_at only; checking sets checked_at; renaming keeps checked_at")
    func fieldTimestamps() async throws {
        let database = try await TestDatabase.make()
        let clock = TickingClock()
        let repository = ShoppingRepositoryImpl(database: database, writer: LocalMutationWriter(clock: clock.now))

        let entry = try await repository.addEntry(NewShoppingEntry(item: .text("Leche"), quantity: 2, unit: "l"))
        var outbox = try await TestDatabase.outbox(database)
        var fields = TestDatabase.fields(of: try #require(outbox.last))
        let insertedAt = try #require(fields["name_updated_at"] as? String)
        #expect(fields["checked"] == nil, "unchecked rows never send the checked group")
        #expect(fields["checked_at"] == nil)
        #expect(fields["checked_by"] == nil)
        #expect(fields["kind"] as? String == "text")

        try await repository.setEntryChecked(id: entry.id, isChecked: true)
        outbox = try await TestDatabase.outbox(database)
        fields = TestDatabase.fields(of: try #require(outbox.last))
        let checkedAt = try #require(fields["checked_at"] as? String)
        #expect(fields["checked"] as? Bool == true)
        #expect(fields["name_updated_at"] as? String == insertedAt)
        #expect(checkedAt > insertedAt)

        try await repository.updateEntry(id: entry.id, text: "Leche sin lactosa", quantity: 3, unit: "l")
        outbox = try await TestDatabase.outbox(database)
        fields = TestDatabase.fields(of: try #require(outbox.last))
        let renamedAt = try #require(fields["name_updated_at"] as? String)
        #expect(renamedAt > checkedAt)
        #expect(fields["checked_at"] as? String == checkedAt)
        #expect(outbox.count == 3)
    }

    @Test("Checking a recipe entry checks its items with their own checked_at")
    func recipeEntryChecksItems() async throws {
        let database = try await TestDatabase.make()
        let clock = TickingClock()
        let writer = LocalMutationWriter(clock: clock.now)
        let products = ProductRepositoryImpl(database: database, writer: writer)
        let shopping = ShoppingRepositoryImpl(database: database, writer: writer)
        let product = try await products.saveProduct(ProductInput(name: "Patatas"))
        let entry = try await shopping.addRecipeEntry(
            NewRecipeShoppingEntry(
                recipeID: UUID(),
                label: "Patatas al airfryer",
                servings: 2,
                items: [NewRecipeShoppingEntry.Item(productID: product.id, quantity: 500, unit: "g")]
            )
        )
        #expect(entry.items.count == 1)

        try await shopping.setEntryChecked(id: entry.id, isChecked: true)

        let items = try await database.writer.read { db in try ShoppingEntryItemRecord.fetchAll(db) }
        #expect(items.allSatisfy { $0.checked && $0.checkedAt != nil })
        let itemMutations = try await TestDatabase.outbox(database).filter {
            $0.tableName == "shopping_entry_items"
        }
        #expect(itemMutations.count == 2)
        #expect(TestDatabase.fields(of: try #require(itemMutations.last))["checked"] as? Bool == true)
    }
}
