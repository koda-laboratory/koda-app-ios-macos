import Foundation
import GRDB

/// The single local write path for product data: every change writes the row **and** its outbox mutation in
/// the same GRDB transaction (the caller's `Database`), with client timestamps and client UUIDs.
///
/// Repositories call it from inside `AppDatabase.write`; the `SyncEngine` later drains the outbox.
struct LocalMutationWriter: Sendable {
    // MARK: - Properties

    private let clock: @Sendable () -> Date

    // MARK: - Lifecycle

    init(clock: @escaping @Sendable () -> Date = { .now }) {
        self.clock = clock
    }

    // MARK: - Context

    /// The household and user of the cached `/me`. Inserts are impossible without a household.
    func context(_ db: Database) throws -> LocalWriteContext {
        guard let householdID = try SyncStateRecord.fetch(db).householdId else {
            throw KodaError(type: .internal, reason: "No household is cached yet; sign in again to load /me.")
        }
        let userID = try String.fetchOne(db, sql: "SELECT user_id FROM me_profile LIMIT 1")
        return LocalWriteContext(householdID: householdID, userID: userID)
    }

    static func newID() -> String {
        UUID().uuidString.lowercased()
    }

    func timestamp() -> String {
        ISO8601Timestamp.string(from: clock())
    }

    // MARK: - Upsert

    /// Inserts or updates `record` and enqueues an `upsert` with the merged row's client-writable fields.
    @discardableResult
    func save<Record: SyncedRecord>(_ record: Record, in db: Database) throws -> Record {
        let context = try context(db)
        let timestamp = timestamp()
        let existing = try Record.fetchOne(db, key: record.id)

        if existing?.isDeleted == true {
            throw KodaError(type: .notFound, reason: "\(Record.syncedTable.rawValue) \(record.id) was deleted.")
        }

        var row = record
        row.householdId =
            existing?.householdId ?? (record.householdId.isEmpty ? context.householdID : record.householdId)
        row.createdAt = existing?.createdAt ?? timestamp
        row.updatedAt = timestamp
        row.updatedBy = context.userID
        row.deletedAt = nil
        row.clientUpdatedAt = timestamp
        row.serverSeq = existing?.serverSeq
        row.prepareForLocalWrite(replacing: existing, timestamp: timestamp)
        try row.save(db)

        let fields = try SyncRowCodec.mutationFields(from: row.databaseDictionary, table: Record.syncedTable)
        try enqueue(.upsert, table: Record.syncedTable, rowID: row.id, fields: fields, timestamp: timestamp, in: db)
        return row
    }

    // MARK: - Delete

    /// Tombstones a row (`deleted_at`), cascades the tombstone to its live children locally (the server does the
    /// same with triggers, so children produce no mutations) and enqueues a `delete`.
    func delete(_ table: SyncedTable, id: String, in db: Database) throws {
        let context = try context(db)
        let timestamp = timestamp()
        guard
            let row = try Row.fetchOne(
                db,
                sql: "SELECT deleted_at FROM \(table.rawValue) WHERE id = ?",
                arguments: [id]
            )
        else {
            throw KodaError(type: .notFound, reason: "\(table.rawValue) \(id) does not exist.")
        }
        guard (row["deleted_at"] as String?) == nil else { return }

        try tombstone(table, ids: [id], timestamp: timestamp, userID: context.userID, in: db)
        try enqueue(.delete, table: table, rowID: id, fields: nil, timestamp: timestamp, in: db)
    }

    // MARK: - Private Methods

    private func tombstone(
        _ table: SyncedTable,
        ids: [String],
        timestamp: String,
        userID: String?,
        in db: Database
    ) throws {
        guard !ids.isEmpty else { return }
        let placeholders = databaseQuestionMarks(count: ids.count)
        var arguments: StatementArguments = [timestamp, timestamp, userID, timestamp]
        arguments += StatementArguments(ids)
        try db.execute(
            sql: """
                UPDATE \(table.rawValue)
                SET deleted_at = ?, updated_at = ?, updated_by = ?, client_updated_at = ?
                WHERE id IN (\(placeholders)) AND deleted_at IS NULL
                """,
            arguments: arguments
        )

        for cascade in table.tombstoneCascades {
            let childIDs = try String.fetchAll(
                db,
                sql: """
                    SELECT id FROM \(cascade.table.rawValue)
                    WHERE \(cascade.column) IN (\(placeholders)) AND deleted_at IS NULL
                    """,
                arguments: StatementArguments(ids)
            )
            try tombstone(cascade.table, ids: childIDs, timestamp: timestamp, userID: userID, in: db)
        }
    }

    private func enqueue(
        _ operation: OutboxRecord.Operation,
        table: SyncedTable,
        rowID: String,
        fields: [String: JSONValue]?,
        timestamp: String,
        in db: Database
    ) throws {
        var entry = OutboxRecord(
            id: nil,
            tableName: table.rawValue,
            rowId: rowID,
            op: operation,
            fieldsJson: try fields.map { try JSONValue.object($0).jsonText() },
            clientTs: timestamp,
            attempts: 0,
            lastError: nil,
            createdAt: timestamp
        )
        try entry.insert(db)
    }
}

struct LocalWriteContext: Sendable, Equatable {
    let householdID: String
    let userID: String?
}
