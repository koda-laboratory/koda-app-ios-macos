import Foundation
import GRDB

/// An outbox entry ready to be pushed.
struct PendingMutation: Sendable, Equatable {
    let outboxID: Int64
    let table: String
    let rowID: String
    let op: String
    let fields: [String: JSONValue]?
    let clientTimestamp: String
}

/// A mutation the server refused; the server version wins.
struct RejectedMutation: Sendable, Equatable {
    let table: String?
    let rowID: String?
    let reason: String
}

/// Outbox, cursor and pulled-row application on the local database. Only the `SyncEngine` uses it.
protocol SyncLocalDataSource: Sendable {
    func pendingMutations(limit: Int) async throws(KodaError) -> [PendingMutation]
    /// Removes pushed entries. Rows rejected because the server has no copy of them are removed locally too.
    func completeMutations(outboxIDs: [Int64], rejected: [RejectedMutation]) async throws(KodaError)
    func recordFailure(outboxIDs: [Int64], reason: String) async throws(KodaError)
    func cursor() async throws(KodaError) -> Int64
    /// Applies one pull page in a single transaction, without outbox entries, and advances the cursor in the same
    /// transaction. Returns the number of rows that changed locally.
    func apply(_ page: SyncPullResponseDTO, syncedAt: Date) async throws(KodaError) -> Int
    /// `reset_required`: drops every synced row (except rows with pending local changes) and rewinds the cursor.
    func resetForFullResync() async throws(KodaError)
    func pendingCount() async throws(KodaError) -> Int
    func observePendingCount() -> AsyncStream<Int>
}

final class SyncLocalDataSourceImpl: SyncLocalDataSource, Sendable {
    /// Rejections meaning the server has no copy of the row; a never-synced local row is then discarded.
    static let reasonsWithoutServerCopy: Set<String> = [
        "not_found", "forbidden", "conflict", "missing_reference", "constraint_violation", "invalid_value",
        "unknown_table", "invalid_op", "invalid_mutation",
    ]

    // MARK: - Properties

    private let database: AppDatabase

    // MARK: - Lifecycle

    init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Outbox

    func pendingMutations(limit: Int) async throws(KodaError) -> [PendingMutation] {
        let records = try await database.read { db in
            try OutboxRecord.order(Column("id")).limit(limit).fetchAll(db)
        }
        return try records.map { record throws(KodaError) in
            let fields: [String: JSONValue]?
            if let fieldsJson = record.fieldsJson {
                guard case .object(let object) = try? JSONValue.parse(jsonText: fieldsJson) else {
                    throw KodaError(type: .storage, reason: "Corrupted outbox entry \(record.id ?? -1).")
                }
                fields = object
            } else {
                fields = nil
            }
            return PendingMutation(
                outboxID: record.id ?? 0,
                table: record.tableName,
                rowID: record.rowId,
                op: record.op.rawValue,
                fields: fields,
                clientTimestamp: record.clientTs
            )
        }
    }

    func completeMutations(outboxIDs: [Int64], rejected: [RejectedMutation]) async throws(KodaError) {
        try await database.write { db in
            try OutboxRecord.filter(keys: outboxIDs).deleteAll(db)

            for rejection in rejected where Self.reasonsWithoutServerCopy.contains(rejection.reason) {
                guard let tableName = rejection.table, let table = SyncedTable(rawValue: tableName),
                    let rowID = rejection.rowID
                else { continue }
                let stillPending =
                    try OutboxRecord
                    .filter(Column("table_name") == tableName && Column("row_id") == rowID)
                    .fetchCount(db) > 0
                guard !stillPending else { continue }
                // Only rows the server never had: a synced row comes back with the next pull.
                try db.execute(
                    sql: "DELETE FROM \(table.rawValue) WHERE id = ? AND server_seq IS NULL",
                    arguments: [rowID]
                )
            }
        }
    }

    func recordFailure(outboxIDs: [Int64], reason: String) async throws(KodaError) {
        guard !outboxIDs.isEmpty else { return }
        try await database.write { db in
            var arguments: StatementArguments = [reason]
            arguments += StatementArguments(outboxIDs)
            try db.execute(
                sql: """
                    UPDATE outbox SET attempts = attempts + 1, last_error = ?
                    WHERE id IN (\(databaseQuestionMarks(count: outboxIDs.count)))
                    """,
                arguments: arguments
            )
        }
    }

    func pendingCount() async throws(KodaError) -> Int {
        try await database.read { db in try OutboxRecord.fetchCount(db) }
    }

    func observePendingCount() -> AsyncStream<Int> {
        database.observe { db in try OutboxRecord.fetchCount(db) }
    }

    // MARK: - Pull

    func cursor() async throws(KodaError) -> Int64 {
        try await database.read { db in try SyncStateRecord.fetch(db).cursor }
    }

    func apply(_ page: SyncPullResponseDTO, syncedAt: Date) async throws(KodaError) -> Int {
        let lastSyncAt = ISO8601Timestamp.string(from: syncedAt)
        return try await database.write { db in
            var changed = 0
            var touched: [SyncedTable: Set<String>] = [:]

            for (tableName, rows) in page.changes {
                // Tables unknown to this app version are ignored (forward compatibility).
                guard let table = SyncedTable(rawValue: tableName), !rows.isEmpty else { continue }
                let tableColumns = try db.columns(in: table.rawValue).map(\.name)

                for pulledRow in rows {
                    guard let id = pulledRow["id"]?.stringValue else { continue }
                    let row = Self.compatibleRow(pulledRow, table: table)
                    // Only the columns the server sent: a backend that does not know a newer local column yet
                    // (version skew) leaves its default or current value instead of writing NULL.
                    let columns = tableColumns.filter { row[$0] != nil }
                    let statement = try db.cachedStatement(sql: Self.upsertSQL(table: table, columns: columns))
                    let values = try columns.map { try SyncRowCodec.databaseValue(row[$0]) }
                    try statement.execute(arguments: StatementArguments(values))
                    if db.changesCount > 0 {
                        changed += 1
                        touched[table, default: []].insert(id)
                    }
                }
            }

            try Self.rebasePendingChanges(onto: touched, in: db)
            try db.execute(
                sql: "UPDATE sync_state SET cursor = ?, last_sync_at = ? WHERE id = 1",
                arguments: [page.cursor, lastSyncAt]
            )
            return changed
        }
    }

    func resetForFullResync() async throws(KodaError) {
        try await database.write { db in
            for table in SyncedTable.allCases {
                try db.execute(
                    sql: """
                        DELETE FROM \(table.rawValue)
                        WHERE id NOT IN (SELECT row_id FROM outbox WHERE table_name = ?)
                        """,
                    arguments: [table.rawValue]
                )
            }
            try db.execute(sql: "UPDATE sync_state SET cursor = 0 WHERE id = 1")
        }
    }

    // MARK: - Private Methods

    /// Fills fields a backend without the third revision does not send yet: the shopping `status` follows
    /// `checked`.
    private static func compatibleRow(_ row: [String: JSONValue], table: SyncedTable) -> [String: JSONValue] {
        guard table.usesFieldLevelConflicts, row["status"] == nil, case .bool(let checked)? = row["checked"] else {
            return row
        }
        var row = row
        row["status"] = .string(checked ? "have" : "pending")
        return row
    }

    /// Upsert by id. Rows are complete, so the order of tables and rows does not matter; an older copy
    /// (lower `server_seq`) never overwrites a newer one.
    private static func upsertSQL(table: SyncedTable, columns: [String]) -> String {
        let columnList = columns.map { "\"\($0)\"" }.joined(separator: ", ")
        let updates = columns.filter { $0 != "id" }.map { "\"\($0)\" = excluded.\"\($0)\"" }.joined(separator: ", ")
        return """
            INSERT INTO \(table.rawValue) (\(columnList)) VALUES (\(databaseQuestionMarks(count: columns.count)))
            ON CONFLICT(id) DO UPDATE SET \(updates)
            WHERE excluded.server_seq IS NULL OR \(table.rawValue).server_seq IS NULL
                OR excluded.server_seq >= \(table.rawValue).server_seq
            """
    }

    /// Re-applies local mutations that have not been pushed yet on top of freshly pulled rows, so the UI keeps
    /// showing them until the server decides.
    private static func rebasePendingChanges(onto touched: [SyncedTable: Set<String>], in db: Database) throws {
        guard !touched.isEmpty else { return }
        let pending = try OutboxRecord.order(Column("id")).fetchAll(db)
        for entry in pending {
            guard let table = SyncedTable(rawValue: entry.tableName), touched[table]?.contains(entry.rowId) == true
            else { continue }

            switch entry.op {
            case .delete:
                try db.execute(
                    sql: "UPDATE \(table.rawValue) SET deleted_at = COALESCE(deleted_at, ?) WHERE id = ?",
                    arguments: [entry.clientTs, entry.rowId]
                )
            case .upsert:
                guard let fieldsJson = entry.fieldsJson,
                    case .object(let fields) = try JSONValue.parse(jsonText: fieldsJson)
                else { continue }
                let columns = Set(try db.columns(in: table.rawValue).map(\.name))
                let assignments = fields.keys.sorted().filter {
                    columns.contains($0) && $0 != "id" && $0 != "household_id"
                }
                guard !assignments.isEmpty else { continue }
                var arguments = StatementArguments(try assignments.map { try SyncRowCodec.databaseValue(fields[$0]) })
                arguments += [entry.rowId]
                try db.execute(
                    sql: """
                        UPDATE \(table.rawValue) SET \(assignments.map { "\"\($0)\" = ?" }.joined(separator: ", "))
                        WHERE id = ?
                        """,
                    arguments: arguments
                )
            }
        }
    }
}
