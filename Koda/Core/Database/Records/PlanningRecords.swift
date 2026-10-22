import GRDB

struct MealPlanDraftRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.mealPlanDrafts

    var id: String
    var householdId: String
    var fromDate: String
    var toDate: String
    var status: String
    var source: String
    var rationale: String?
    var createdBy: String?
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?
}

struct MealPlanEntryRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.mealPlanEntries

    var id: String
    var householdId: String
    var date: String
    var slot: String
    var recipeId: String?
    var freeText: String?
    var servings: Double?
    var note: String?
    var position: Int
    var draftId: String?
    /// `HH:MM:SS` override of the household slot time.
    var scheduledTime: String?
    /// "No lo comimos": the meal is not auto-logged again.
    var skippedAt: String?
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?
}

struct ConsumptionRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.consumptions

    var id: String
    var householdId: String
    var recipeId: String
    var eatenOn: String
    var slot: String?
    var servings: Double?
    var mealPlanEntryId: String?
    var loggedBy: String?
    /// `auto` | `manual` | `siri` | `mcp`.
    var source: String = "manual"
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?
}
