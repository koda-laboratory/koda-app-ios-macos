import GRDB

struct RecipeRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.recipes

    var id: String
    var householdId: String
    var name: String
    /// JSON array of `meal_slot` values.
    var mealTypes: String
    /// JSON array of nutrient tags.
    var nutrients: String
    var timeMinutes: Int?
    var servings: Double
    /// JSON array of strings.
    var steps: String
    var notes: String?
    var imagePath: String?
    var emoji: String?
    var isFavorite: Bool
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?
}

struct RecipeIngredientRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.recipeIngredients

    var id: String
    var householdId: String
    var recipeId: String
    var productId: String
    var quantity: Double?
    var unit: String?
    var position: Int
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?
}

struct RecipeComponentRecord: SyncedRecord, Equatable {
    static let syncedTable = SyncedTable.recipeComponents

    var id: String
    var householdId: String
    var parentRecipeId: String
    var childRecipeId: String
    var servingsFactor: Double
    var position: Int
    var createdAt: String?
    var updatedAt: String?
    var updatedBy: String?
    var deletedAt: String?
    var clientUpdatedAt: String?
    var serverSeq: Int64?
}
