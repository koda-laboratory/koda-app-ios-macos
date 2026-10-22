import GRDB

/// A pending mutation, written in the same transaction as the row it describes.
struct OutboxRecord: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "outbox"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    enum Operation: String, Codable, Sendable {
        case upsert
        case delete
    }

    var id: Int64?
    var tableName: String
    var rowId: String
    var op: Operation
    /// JSON object with the fields to send (`nil` for deletes).
    var fieldsJson: String?
    var clientTs: String
    var attempts: Int
    var lastError: String?
    var createdAt: String

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Single-row sync bookkeeping (`id = 1`).
struct SyncStateRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "sync_state"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    var id: Int
    var cursor: Int64
    var lastSyncAt: String?
    var householdId: String?

    static func fetch(_ db: Database) throws -> SyncStateRecord {
        try SyncStateRecord.fetchOne(db, key: 1) ?? SyncStateRecord(id: 1, cursor: 0)
    }
}

struct MeProfileRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "me_profile"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    var userId: String
    var displayName: String?
    var avatarEmoji: String?
    var fetchedAt: String
}

struct MeHouseholdRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "me_households"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    var id: String
    var name: String
    var timezone: String
    var role: String
    var position: Int
    /// JSON object `{"breakfast":"HH:MM",…}`; `nil` until the backend sends it.
    var slotTimes: String?
    var shoppingWeekday: Int?
}

struct MeMemberRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "me_members"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    var householdId: String
    var userId: String
    var role: String
    var displayName: String?
    var avatarEmoji: String?
    var position: Int
}
