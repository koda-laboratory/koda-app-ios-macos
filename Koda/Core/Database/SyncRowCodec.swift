import Foundation
import GRDB

/// Converts between the JSON representation of a synced row (`/sync/pull` rows, outbox `fields`) and the
/// local column values.
enum SyncRowCodec {
    /// JSON value of a mutation field from the stored column value.
    static func jsonValue(_ value: DatabaseValue, column: String, table: SyncedTable) throws -> JSONValue {
        switch value.storage {
        case .null:
            return .null
        case .int64(let int):
            return table.booleanColumns.contains(column) ? .bool(int != 0) : .int(int)
        case .double(let double):
            return .double(double)
        case .string(let string):
            return table.jsonColumns.contains(column) ? try JSONValue.parse(jsonText: string) : .string(string)
        case .blob(let data):
            return .string(String(bytes: data, encoding: .utf8) ?? "")
        }
    }

    /// Local column value from a JSON value (arrays and objects become JSON text, booleans 0/1).
    static func databaseValue(_ value: JSONValue?) throws -> DatabaseValue {
        guard let value else { return .null }
        switch value {
        case .null: return .null
        case .bool(let bool): return bool.databaseValue
        case .int(let int): return int.databaseValue
        case .double(let double): return double.databaseValue
        case .string(let string): return string.databaseValue
        case .array, .object: return try value.jsonText().databaseValue
        }
    }

    /// Mutation `fields` for a stored row: every client-writable column (`household_id` included, since the server
    /// only uses it on insert).
    ///
    /// For the shopping tables, the `status`/`checked` group is only sent once `checked_at` exists; otherwise the server
    /// would default its timestamp to `client_ts` and could undo a newer check from another device.
    static func mutationFields(
        from dictionary: [String: DatabaseValue],
        table: SyncedTable
    ) throws -> [String: JSONValue] {
        var fields: [String: JSONValue] = [:]
        for (column, value) in dictionary {
            let isServerOwned = SyncedTable.serverOwnedColumns.contains(column) && column != "household_id"
            guard !isServerOwned, !table.serverManagedColumns.contains(column) else { continue }
            fields[column] = try jsonValue(value, column: column, table: table)
        }
        if table.usesFieldLevelConflicts, fields["checked_at"] == nil || fields["checked_at"] == .null {
            fields.removeValue(forKey: "checked")
            fields.removeValue(forKey: "checked_at")
            fields.removeValue(forKey: "status")
        }
        return fields
    }
}
