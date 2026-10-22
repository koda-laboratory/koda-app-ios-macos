import GRDB

/// A GRDB record mirroring one row of a synced table. Records never leave the data layer: repositories map
/// them to domain models.
protocol SyncedRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    static var syncedTable: SyncedTable { get }

    var id: String { get }
    var householdId: String { get set }
    var createdAt: String? { get set }
    var updatedAt: String? { get set }
    var updatedBy: String? { get set }
    var deletedAt: String? { get set }
    var clientUpdatedAt: String? { get set }
    var serverSeq: Int64? { get set }

    /// Hook to maintain derived columns before a local write (for example the shopping list's per-field
    /// last-writer-wins timestamps). `existing` is the row currently stored, if any.
    mutating func prepareForLocalWrite(replacing existing: Self?, timestamp: String)
}

extension SyncedRecord {
    static var databaseTableName: String { syncedTable.rawValue }
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    mutating func prepareForLocalWrite(replacing existing: Self?, timestamp: String) {}

    var isDeleted: Bool { deletedAt != nil }

    /// Live (not tombstoned) rows.
    static func live() -> QueryInterfaceRequest<Self> {
        filter(Column("deleted_at") == nil)
    }
}
