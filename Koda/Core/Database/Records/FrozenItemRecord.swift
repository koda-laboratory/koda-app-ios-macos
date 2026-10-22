import GRDB

/// What is in the freezer and for which meal. The server creates and maintains these rows from the shopping
/// status; the app only writes `resolved_at` ("Hecho").
struct FrozenItemRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.frozenItems

    var id: String
    var householdId: String
    var productId: String
    var shoppingEntryId: String?
    var shoppingEntryItemId: String?
    var mealPlanEntryId: String?
    var frozenAt: String?
    var defrostRemindAt: String?
    var remindedAt: String?
    var resolvedAt: String?
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?
}
