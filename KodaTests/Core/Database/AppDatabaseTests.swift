import Foundation
import GRDB
import Testing

@testable import Koda

@Suite("AppDatabase migrations and helpers")
struct AppDatabaseTests {
    @Test("Migrations create every synced table with every server column")
    func migrationsApply() async throws {
        let database = try await TestDatabase.make(signedIn: false)
        let expected: [SyncedTable: [String]] = [
            .stores: ["name", "color"],
            .products: ["category", "default_unit", "price_per_kg", "price_total", "servings", "servings_per_week"],
            .productStores: ["product_id", "store_id"],
            .recipes: [
                "meal_types", "nutrients", "time_minutes", "steps", "image_path", "image_source", "is_favorite",
            ],
            .recipeIngredients: ["recipe_id", "product_id", "quantity", "unit", "position"],
            .recipeComponents: ["parent_recipe_id", "child_recipe_id", "servings_factor"],
            .recipePhotos: ["recipe_id", "storage_path", "width", "height", "position"],
            .mealPlanDrafts: ["from_date", "to_date", "status", "source", "rationale", "created_by"],
            .mealPlanEntries: ["date", "slot", "recipe_id", "free_text", "draft_id"],
            .consumptions: ["eaten_on", "slot", "meal_plan_entry_id", "logged_by"],
            .shoppingEntries: ["kind", "checked", "checked_at", "checked_by", "name_updated_at", "source"],
            .shoppingEntryItems: ["entry_id", "product_id", "checked", "checked_at"],
        ]
        let syncColumns = [
            "id", "household_id", "created_at", "updated_at", "updated_by", "deleted_at", "client_updated_at",
            "server_seq",
        ]

        let columns = try await database.writer.read { db in
            var result: [SyncedTable: Set<String>] = [:]
            for table in SyncedTable.allCases {
                result[table] = Set(try db.columns(in: table.rawValue).map(\.name))
            }
            return result
        }
        for table in SyncedTable.allCases {
            let tableColumns = try #require(columns[table])
            for column in syncColumns + (expected[table] ?? []) {
                #expect(tableColumns.contains(column), "\(table.rawValue) is missing \(column)")
            }
        }

        let bookkeeping = try await database.writer.read { db in
            (
                try db.tableExists("outbox"), try db.tableExists("me_profile"),
                try SyncStateRecord.fetch(db).cursor
            )
        }
        #expect(bookkeeping.0)
        #expect(bookkeeping.1)
        #expect(bookkeeping.2 == 0)
    }

    @Test("Erasing removes rows, outbox and cached household but keeps the schema")
    func eraseAllData() async throws {
        let database = try await TestDatabase.make()
        let writer = LocalMutationWriter()
        try await database.write { db in
            try writer.save(StoreRecord(id: LocalMutationWriter.newID(), householdId: "", name: "Aldi"), in: db)
        }

        try await database.eraseAllData()

        #expect(try await TestDatabase.count("stores", in: database) == 0)
        #expect(try await TestDatabase.count("outbox", in: database) == 0)
        #expect(try await TestDatabase.count("me_profile", in: database) == 0)
        #expect(try await TestDatabase.string("SELECT household_id FROM sync_state", in: database) == nil)
    }

    @Test("Observation emits the current value and then committed changes")
    func observationEmitsChanges() async throws {
        let database = try await TestDatabase.make()
        var iterator = database.observe { db in try StoreRecord.fetchCount(db) }.makeAsyncIterator()
        #expect(await iterator.next() == 0)

        let writer = LocalMutationWriter()
        try await database.write { db in
            try writer.save(StoreRecord(id: LocalMutationWriter.newID(), householdId: "", name: "Aldi"), in: db)
        }
        #expect(await iterator.next() == 1)
    }

    @Test(
        "Server and client timestamps parse to the same instant",
        arguments: [
            ("2026-10-22T10:00:00.123456+00:00", 1_792_663_200.123),
            ("2026-10-22T10:00:00.123Z", 1_792_663_200.123),
            ("2026-10-22T12:00:00+02:00", 1_792_663_200.0),
        ]
    )
    func timestampsParse(value: String, expected: TimeInterval) throws {
        let date = try #require(ISO8601Timestamp.date(from: value))
        #expect(abs(date.timeIntervalSince1970 - expected) < 0.001)
    }

    @Test("Local days compute week starts and offsets")
    func localDays() throws {
        let day = try #require(LocalDay("2026-10-22"))  // Thursday
        #expect(day.startOfWeek.description == "2026-10-19")
        #expect(day.adding(days: 10).description == "2026-11-01")
        #expect(LocalDay("2026-13-01") == nil)
    }
}
