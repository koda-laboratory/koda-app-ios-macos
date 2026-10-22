import GRDB

struct ShoppingEntryRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.shoppingEntries

    var id: String
    var householdId: String
    var kind: String
    var productId: String?
    var recipeId: String?
    var text: String?
    var quantity: Double?
    var unit: String?
    var checked: Bool
    /// `pending` | `have` | `frozen`; `checked` always equals `status != pending`.
    var status: String = "pending"
    var checkedAt: String?
    var checkedBy: String?
    var nameUpdatedAt: String?
    var source: String
    var mealPlanEntryId: String?
    var position: Int
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?

    /// Maintains the per-field last-writer-wins timestamps the server resolves with: `checked_at` when the
    /// status changes and `name_updated_at` when `text`, `quantity` or `unit` change.
    mutating func prepareForLocalWrite(replacing existing: ShoppingEntryRecord?, timestamp: String) {
        checked = status != "pending"
        guard let existing else {
            if checked { checkedAt = timestamp }
            nameUpdatedAt = timestamp
            return
        }
        if existing.status != status || existing.checked != checked { checkedAt = timestamp }
        if existing.text != text || existing.quantity != quantity || existing.unit != unit {
            nameUpdatedAt = timestamp
        }
    }
}

struct ShoppingEntryItemRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.shoppingEntryItems

    var id: String
    var householdId: String
    var entryId: String
    var productId: String
    var quantity: Double?
    var unit: String?
    var checked: Bool
    /// `pending` | `have` | `frozen`; `checked` always equals `status != pending`.
    var status: String = "pending"
    var checkedAt: String?
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?

    /// `shopping_entry_items` only resolve the status group per field (by `checked_at`).
    mutating func prepareForLocalWrite(replacing existing: ShoppingEntryItemRecord?, timestamp: String) {
        checked = status != "pending"
        let statusChanged = existing.map { $0.status != status || $0.checked != checked } ?? checked
        if statusChanged {
            checkedAt = timestamp
        }
    }
}
