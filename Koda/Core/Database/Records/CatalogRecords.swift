import GRDB

struct StoreRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.stores

    var id: String
    var householdId: String
    var name: String
    var color: String?
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?
}

struct ProductRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.products

    var id: String
    var householdId: String
    var name: String
    var category: String
    var defaultUnit: String?
    var pricePerKg: Double?
    var priceTotal: Double?
    var servings: Double?
    var servingsPerWeek: Double?
    var notes: String?
    var emoji: String?
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?
}

struct ProductStoreRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.productStores

    var id: String
    var householdId: String
    var productId: String
    var storeId: String
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?
}
