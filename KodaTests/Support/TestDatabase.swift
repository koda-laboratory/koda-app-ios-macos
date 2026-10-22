import Foundation
import GRDB

@testable import Koda

/// In-memory databases with the real migrations.
enum TestDatabase {
    static let householdID = "11111111-1111-4111-8111-111111111111"
    static let userID = "22222222-2222-4222-8222-222222222222"

    /// An empty database; `signedIn` caches a household and user as `/me` would.
    static func make(signedIn: Bool = true) async throws -> AppDatabase {
        let database = try AppDatabase.makeInMemory()
        if signedIn {
            try await database.writer.write { db in
                try db.execute(sql: "UPDATE sync_state SET household_id = ? WHERE id = 1", arguments: [householdID])
                try db.execute(
                    sql: "INSERT INTO me_profile (user_id, display_name, fetched_at) VALUES (?, 'Test', ?)",
                    arguments: [userID, "2026-10-22T10:00:00.000Z"]
                )
                try db.execute(
                    sql: """
                        INSERT INTO me_households (id, name, timezone, role, position)
                        VALUES (?, 'Casa', 'Europe/Madrid', 'owner', 0)
                        """,
                    arguments: [householdID]
                )
            }
        }
        return database
    }

    static func count(_ table: String, in database: AppDatabase, where condition: String = "1") async throws -> Int {
        try await database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table) WHERE \(condition)") ?? 0
        }
    }

    static func string(_ sql: String, in database: AppDatabase) async throws -> String? {
        try await database.writer.read { db in try String.fetchOne(db, sql: sql) }
    }

    static func outbox(_ database: AppDatabase) async throws -> [OutboxRecord] {
        try await database.writer.read { db in try OutboxRecord.order(Column("id")).fetchAll(db) }
    }

    static func fields(of entry: OutboxRecord) -> [String: Any] {
        TestJSON.object(entry.fieldsJson.map { Data($0.utf8) })
    }
}

/// Server-shaped rows for `/sync/pull` pages.
enum ServerRows {
    static func sync(_ id: String, seq: Int, deleted: Bool = false) -> [String: Any] {
        [
            "id": id,
            "household_id": TestDatabase.householdID,
            "created_at": "2026-10-22T10:00:00.123456+00:00",
            "updated_at": "2026-10-22T10:00:00.123456+00:00",
            "updated_by": TestDatabase.userID,
            "deleted_at": deleted ? "2026-10-22T11:00:00+00:00" : NSNull(),
            "client_updated_at": "2026-10-22T10:00:00+00:00",
            "server_seq": seq,
        ]
    }

    static func product(_ id: String, name: String, seq: Int, category: String = "food") -> [String: Any] {
        sync(id, seq: seq).merging([
            "name": name, "category": category, "default_unit": NSNull(), "price_per_kg": 1.5,
            "price_total": NSNull(), "servings": NSNull(), "servings_per_week": NSNull(), "notes": NSNull(),
            "emoji": "🥛",
        ]) { $1 }
    }

    static func recipe(_ id: String, name: String, seq: Int, deleted: Bool = false) -> [String: Any] {
        sync(id, seq: seq, deleted: deleted).merging([
            "name": name, "meal_types": ["lunch", "dinner"], "nutrients": ["protein"], "time_minutes": 30,
            "servings": 2, "steps": ["Cortar", "Hornear"], "notes": NSNull(), "image_path": NSNull(),
            "emoji": "🍗", "is_favorite": true,
        ]) { $1 }
    }

    static func ingredient(_ id: String, recipe: String, product: String, quantity: Double, seq: Int) -> [String: Any] {
        sync(id, seq: seq).merging([
            "recipe_id": recipe, "product_id": product, "quantity": quantity, "unit": "g", "position": 0,
        ]) { $1 }
    }

    static func pull(
        _ changes: [String: [[String: Any]]],
        cursor: Int,
        hasMore: Bool = false,
        resetRequired: Bool = false
    ) -> Data {
        TestJSON.data(["changes": changes, "cursor": cursor, "has_more": hasMore, "reset_required": resetRequired])
    }

    static func uuid(_ index: Int) -> String {
        String(format: "00000000-0000-4000-8000-%012d", index)
    }
}
