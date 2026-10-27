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
            .products: [
                "category", "default_unit", "price_per_kg", "price_total", "servings", "servings_per_week",
                "image_path", "image_source",
            ],
            .productStores: ["product_id", "store_id"],
            .productPhotos: ["product_id", "storage_path", "width", "height", "position"],
            .recipes: [
                "meal_types", "nutrients", "time_minutes", "steps", "image_path", "image_source", "is_favorite",
            ],
            .recipeIngredients: ["recipe_id", "product_id", "quantity", "unit", "position"],
            .recipeComponents: ["parent_recipe_id", "child_recipe_id", "servings_factor"],
            .recipePhotos: ["recipe_id", "storage_path", "width", "height", "position"],
            .recipeLinks: ["recipe_id", "url", "position"],
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

    @Test("v4 rewinds the pull cursor once and keeps local rows, the outbox and queued uploads")
    func v4ForcesFullRepull() async throws {
        let queue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(queue, upTo: "v3_recipe_images")
        try await queue.write { db in
            try db.execute(sql: "UPDATE sync_state SET cursor = 4242, household_id = 'h' WHERE id = 1")
            try db.execute(
                sql: """
                    INSERT INTO products (id, household_id, name, server_seq) VALUES ('p1', 'h', 'Leche', 10);
                    INSERT INTO outbox (table_name, row_id, op, fields_json, client_ts, created_at)
                    VALUES ('products', 'p1', 'upsert', '{"name":"Leche"}', '2026-10-27T10:00:00Z',
                            '2026-10-27T10:00:00Z');
                    INSERT INTO pending_image_uploads (storage_path, created_at) VALUES ('h/r/1.jpg', '2026-10-27');
                    """
            )
        }

        let database = try AppDatabase(queue)

        let state = try await database.read { db in
            (
                try SyncStateRecord.fetch(db),
                try String.fetchOne(db, sql: "SELECT name FROM products WHERE id = 'p1'"),
                try OutboxRecord.fetchCount(db),
                try String.fetchOne(db, sql: "SELECT bucket FROM pending_image_uploads")
            )
        }
        #expect(state.0.cursor == 0)
        #expect(state.0.householdId == "h")
        #expect(state.1 == "Leche")
        #expect(state.2 == 1)
        #expect(state.3 == ImageBucket.recipes.rawValue)

        // Later launches do not rewind it again.
        try await database.write { db in try db.execute(sql: "UPDATE sync_state SET cursor = 50 WHERE id = 1") }
        let reopened = try AppDatabase(queue)
        #expect(try await reopened.read { db in try SyncStateRecord.fetch(db).cursor } == 50)
    }

    @Test("A full re-pull fills the new columns and tables of rows pulled before v4")
    func repullFillsNewColumns() async throws {
        let database = try await TestDatabase.make()
        let local = SyncLocalDataSourceImpl(database: database)
        let productID = LocalMutationWriter.newID()
        let page = SyncPullResponseDTO(
            changes: [
                "products": [
                    [
                        "id": .string(productID), "household_id": .string(TestDatabase.householdID),
                        "name": .string("Leche"), "category": .string("basics"),
                        "image_path": .string("h/\(productID)/a.jpg"), "image_source": .string("photo"),
                        "server_seq": .int(7),
                    ]
                ],
                "product_photos": [
                    [
                        "id": .string(LocalMutationWriter.newID()), "household_id": .string(TestDatabase.householdID),
                        "product_id": .string(productID), "storage_path": .string("h/\(productID)/a.jpg"),
                        "position": .int(0), "server_seq": .int(8),
                    ]
                ],
            ],
            cursor: 8,
            hasMore: false,
            resetRequired: false
        )

        _ = try await local.apply(page, syncedAt: .now)

        #expect(
            try await TestDatabase.string("SELECT image_path FROM products", in: database) == "h/\(productID)/a.jpg"
        )
        #expect(try await TestDatabase.count("product_photos", in: database) == 1)
        #expect(try await TestDatabase.count("outbox", in: database) == 0)
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
