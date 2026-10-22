import Foundation
import GRDB

final class RecipeRepositoryImpl: RecipeRepository, Sendable {
    // MARK: - Properties

    private let database: AppDatabase
    private let writer: LocalMutationWriter

    // MARK: - Lifecycle

    init(database: AppDatabase, writer: LocalMutationWriter) {
        self.database = database
        self.writer = writer
    }

    // MARK: - Observation

    func observeRecipes() -> AsyncStream<[Recipe]> {
        database.observe { db in
            try RecipeRecord.live()
                .order(Column("name").collating(.localizedCaseInsensitiveCompare))
                .fetchAll(db)
                .compactMap(Recipe.init(record:))
        }
    }

    func observeRecipeDetail(id: UUID) -> AsyncStream<RecipeDetail?> {
        let recipeID = id.lowercasedString
        return database.observe { db in try Self.fetchDetail(recipeID: recipeID, in: db) }
    }

    func recipeGraph() async throws(KodaError) -> RecipeGraph {
        try await database.read(Self.fetchGraph)
    }

    // MARK: - Mutations

    @discardableResult
    func saveRecipe(_ input: RecipeInput) async throws(KodaError) -> Recipe {
        let writer = writer
        return try await database.write { db in
            let id = input.id?.lowercasedString ?? LocalMutationWriter.newID()
            var record = try RecipeRecord.fetchOne(db, key: id) ?? RecipeRecord(id: id, name: input.name)
            record.name = input.name
            record.mealTypes = try Self.jsonText(input.mealTypes.map(\.rawValue))
            record.nutrients = try Self.jsonText(input.nutrients.map(\.rawValue))
            record.timeMinutes = input.timeMinutes
            record.servings = input.servings
            record.steps = try Self.jsonText(input.steps)
            record.notes = input.notes
            record.emoji = input.emoji
            record.isFavorite = input.isFavorite
            let saved = try writer.save(record, in: db)
            guard let recipe = Recipe(record: saved) else {
                throw KodaError(type: .internal, reason: "Invalid recipe \(saved.id).")
            }
            return recipe
        }
    }

    func setFavorite(recipeID: UUID, isFavorite: Bool) async throws(KodaError) {
        let writer = writer
        try await database.write { db in
            guard var record = try RecipeRecord.fetchOne(db, key: recipeID.lowercasedString) else {
                throw KodaError(type: .notFound, reason: "Recipe \(recipeID) not found.")
            }
            record.isFavorite = isFavorite
            try writer.save(record, in: db)
        }
    }

    func deleteRecipe(id: UUID) async throws(KodaError) {
        let writer = writer
        try await database.write { db in try writer.delete(.recipes, id: id.lowercasedString, in: db) }
    }

    @discardableResult
    func addIngredient(_ input: RecipeIngredientInput) async throws(KodaError) -> UUID {
        let writer = writer
        let id = UUID()
        try await database.write { db in
            let recipeID = input.recipeID.lowercasedString
            let position =
                try Int.fetchOne(
                    db,
                    sql:
                        "SELECT COALESCE(MAX(position), -1) + 1 FROM recipe_ingredients WHERE recipe_id = ? AND deleted_at IS NULL",
                    arguments: [recipeID]
                ) ?? 0
            try writer.save(
                RecipeIngredientRecord(
                    id: id.lowercasedString,
                    householdId: "",
                    recipeId: recipeID,
                    productId: input.productID.lowercasedString,
                    quantity: input.quantity,
                    unit: input.unit,
                    position: position
                ),
                in: db
            )
        }
        return id
    }

    func removeIngredient(id: UUID) async throws(KodaError) {
        let writer = writer
        try await database.write { db in try writer.delete(.recipeIngredients, id: id.lowercasedString, in: db) }
    }

    @discardableResult
    func addComponent(parentID: UUID, childID: UUID, servingsFactor: Double) async throws(KodaError) -> UUID {
        let writer = writer
        let id = UUID()
        try await database.write { db in
            let parent = parentID.lowercasedString
            let position =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COALESCE(MAX(position), -1) + 1 FROM recipe_components
                        WHERE parent_recipe_id = ? AND deleted_at IS NULL
                        """,
                    arguments: [parent]
                ) ?? 0
            try writer.save(
                RecipeComponentRecord(
                    id: id.lowercasedString,
                    householdId: "",
                    parentRecipeId: parent,
                    childRecipeId: childID.lowercasedString,
                    servingsFactor: servingsFactor,
                    position: position
                ),
                in: db
            )
        }
        return id
    }

    func removeComponent(id: UUID) async throws(KodaError) {
        let writer = writer
        try await database.write { db in try writer.delete(.recipeComponents, id: id.lowercasedString, in: db) }
    }

    // MARK: - Queries

    private static func fetchDetail(recipeID: String, in db: Database) throws -> RecipeDetail? {
        guard let record = try RecipeRecord.live().filter(key: recipeID).fetchOne(db),
            let recipe = Recipe(record: record)
        else {
            return nil
        }

        let ingredientRows = try Row.fetchAll(
            db,
            sql: """
                SELECT i.id, i.recipe_id, i.product_id, i.quantity, i.unit, i.position,
                       p.name AS product_name, p.emoji AS product_emoji
                FROM recipe_ingredients i
                JOIN products p ON p.id = i.product_id AND p.deleted_at IS NULL
                WHERE i.recipe_id = ? AND i.deleted_at IS NULL
                ORDER BY i.position
                """,
            arguments: [recipeID]
        )
        let ingredients = ingredientRows.compactMap { row -> RecipeIngredient? in
            guard let id = UUID(uuidString: row["id"]), let productID = UUID(uuidString: row["product_id"]) else {
                return nil
            }
            return RecipeIngredient(
                id: id,
                recipeID: recipe.id,
                productID: productID,
                productName: row["product_name"],
                productEmoji: row["product_emoji"],
                quantity: row["quantity"],
                unit: row["unit"],
                position: row["position"]
            )
        }

        let componentRows = try Row.fetchAll(
            db,
            sql: """
                SELECT c.id, c.child_recipe_id, c.servings_factor, c.position, r.name AS child_name, r.emoji AS child_emoji
                FROM recipe_components c
                JOIN recipes r ON r.id = c.child_recipe_id AND r.deleted_at IS NULL
                WHERE c.parent_recipe_id = ? AND c.deleted_at IS NULL
                ORDER BY c.position
                """,
            arguments: [recipeID]
        )
        let components = componentRows.compactMap { row -> RecipeComponent? in
            guard let id = UUID(uuidString: row["id"]), let childID = UUID(uuidString: row["child_recipe_id"]) else {
                return nil
            }
            return RecipeComponent(
                id: id,
                parentRecipeID: recipe.id,
                childRecipeID: childID,
                childRecipeName: row["child_name"],
                childRecipeEmoji: row["child_emoji"],
                servingsFactor: row["servings_factor"],
                position: row["position"]
            )
        }

        return RecipeDetail(recipe: recipe, ingredients: ingredients, components: components)
    }

    @Sendable
    private static func fetchGraph(_ db: Database) throws -> RecipeGraph {
        var graph = RecipeGraph()
        for record in try RecipeRecord.live().fetchAll(db) {
            guard let id = UUID(uuidString: record.id) else { continue }
            graph.recipes[id] = RecipeGraph.Node(id: id, name: record.name, servings: record.servings)
        }

        let ingredientRows = try Row.fetchAll(
            db,
            sql: """
                SELECT i.recipe_id, i.product_id, i.quantity, i.unit, i.position, p.name AS product_name
                FROM recipe_ingredients i
                JOIN products p ON p.id = i.product_id AND p.deleted_at IS NULL
                WHERE i.deleted_at IS NULL
                """
        )
        for row in ingredientRows {
            guard let recipeID = UUID(uuidString: row["recipe_id"]), let productID = UUID(uuidString: row["product_id"])
            else { continue }
            graph.ingredients[recipeID, default: []].append(
                RecipeGraph.Ingredient(
                    productID: productID,
                    productName: row["product_name"],
                    quantity: row["quantity"],
                    unit: row["unit"],
                    position: row["position"]
                )
            )
        }

        for record in try RecipeComponentRecord.live().fetchAll(db) {
            guard let parentID = UUID(uuidString: record.parentRecipeId),
                let childID = UUID(uuidString: record.childRecipeId)
            else { continue }
            graph.components[parentID, default: []].append(
                RecipeGraph.Component(
                    childRecipeID: childID,
                    servingsFactor: record.servingsFactor,
                    position: record.position
                )
            )
        }
        return graph
    }

    private static func jsonText(_ values: [String]) throws -> String {
        try JSONValue.array(values.map(JSONValue.string)).jsonText()
    }
}

// MARK: - Catalog, Notes and Contents

extension RecipeRepositoryImpl {
    func observeCatalog() -> AsyncStream<[RecipeCatalogItem]> {
        database.observe { db in
            let recipes = try RecipeRecord.live()
                .order(Column("name").collating(.localizedCaseInsensitiveCompare))
                .fetchAll(db)
                .compactMap(Recipe.init(record:))
            let ingredientRows = try Row.fetchAll(
                db,
                sql: """
                    SELECT i.recipe_id, p.name FROM recipe_ingredients i
                    JOIN products p ON p.id = i.product_id AND p.deleted_at IS NULL
                    WHERE i.deleted_at IS NULL
                    ORDER BY i.position
                    """
            )
            var names: [String: [String]] = [:]
            for row in ingredientRows {
                names[row["recipe_id"], default: []].append(row["name"])
            }
            let stats = try Self.fetchStats(recipeID: nil, in: db)
            return recipes.map { recipe in
                RecipeCatalogItem(
                    recipe: recipe,
                    ingredientNames: names[recipe.id.lowercasedString] ?? [],
                    stats: stats[recipe.id.lowercasedString] ?? .never
                )
            }
        }
    }

    func observeStats(recipeID: UUID) -> AsyncStream<RecipeStats> {
        let id = recipeID.lowercasedString
        return database.observe { db in try Self.fetchStats(recipeID: id, in: db)[id] ?? .never }
    }

    func updateNotes(recipeID: UUID, notes: String?) async throws(KodaError) {
        let writer = writer
        try await database.write { db in
            guard var record = try RecipeRecord.live().filter(key: recipeID.lowercasedString).fetchOne(db) else {
                throw KodaError(type: .notFound, reason: "Recipe \(recipeID) not found.")
            }
            guard record.notes != notes else { return }
            record.notes = notes
            try writer.save(record, in: db)
        }
    }

    func replaceContents(
        recipeID: UUID,
        ingredients: [RecipeIngredientDraft],
        components: [RecipeComponentDraft]
    ) async throws(KodaError) {
        let writer = writer
        try await database.write { db in
            let parent = recipeID.lowercasedString
            let existingIngredients = try RecipeIngredientRecord.live()
                .filter(Column("recipe_id") == parent)
                .fetchAll(db)
            let keptIngredients = Set(ingredients.compactMap { $0.id?.lowercasedString })
            for record in existingIngredients where !keptIngredients.contains(record.id) {
                try writer.delete(.recipeIngredients, id: record.id, in: db)
            }
            let ingredientsByID = Dictionary(uniqueKeysWithValues: existingIngredients.map { ($0.id, $0) })
            for (position, draft) in ingredients.enumerated() {
                let id = draft.id?.lowercasedString ?? LocalMutationWriter.newID()
                var record =
                    ingredientsByID[id]
                    ?? RecipeIngredientRecord(
                        id: id,
                        householdId: "",
                        recipeId: parent,
                        productId: draft.productID.lowercasedString,
                        quantity: nil,
                        unit: nil,
                        position: position
                    )
                let updated = RecipeIngredientRecord(
                    id: record.id,
                    householdId: record.householdId,
                    recipeId: parent,
                    productId: draft.productID.lowercasedString,
                    quantity: draft.quantity,
                    unit: draft.unit,
                    position: position
                )
                guard
                    ingredientsByID[id] == nil || record.productId != updated.productId
                        || record.quantity != updated.quantity || record.unit != updated.unit
                        || record.position != updated.position
                else { continue }
                record.productId = updated.productId
                record.quantity = updated.quantity
                record.unit = updated.unit
                record.position = position
                try writer.save(record, in: db)
            }

            let existingComponents = try RecipeComponentRecord.live()
                .filter(Column("parent_recipe_id") == parent)
                .fetchAll(db)
            let keptComponents = Set(components.compactMap { $0.id?.lowercasedString })
            for record in existingComponents where !keptComponents.contains(record.id) {
                try writer.delete(.recipeComponents, id: record.id, in: db)
            }
            let componentsByID = Dictionary(uniqueKeysWithValues: existingComponents.map { ($0.id, $0) })
            for (position, draft) in components.enumerated() {
                let id = draft.id?.lowercasedString ?? LocalMutationWriter.newID()
                var record =
                    componentsByID[id]
                    ?? RecipeComponentRecord(
                        id: id,
                        householdId: "",
                        parentRecipeId: parent,
                        childRecipeId: draft.childRecipeID.lowercasedString,
                        servingsFactor: draft.servingsFactor,
                        position: position
                    )
                let isNew = componentsByID[id] == nil
                let changed =
                    record.childRecipeId != draft.childRecipeID.lowercasedString
                    || record.servingsFactor != draft.servingsFactor || record.position != position
                guard isNew || changed else { continue }
                record.childRecipeId = draft.childRecipeID.lowercasedString
                record.servingsFactor = draft.servingsFactor
                record.position = position
                try writer.save(record, in: db)
            }
        }
    }

    /// `recipe_stats` computed locally: times eaten and the last day, per recipe id (lowercase).
    fileprivate static func fetchStats(recipeID: String?, in db: Database) throws -> [String: RecipeStats] {
        let filter = recipeID == nil ? "" : " AND recipe_id = ?"
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT recipe_id, COUNT(*) AS times, MAX(eaten_on) AS last_eaten FROM consumptions
                WHERE deleted_at IS NULL\(filter)
                GROUP BY recipe_id
                """,
            arguments: recipeID.map { [$0] } ?? []
        )
        var stats: [String: RecipeStats] = [:]
        for row in rows {
            stats[row["recipe_id"]] = RecipeStats(
                timesEaten: row["times"],
                lastEatenOn: (row["last_eaten"] as String?).flatMap { LocalDay($0) }
            )
        }
        return stats
    }

}

// MARK: - Mapping

extension Recipe {
    init?(record: RecipeRecord) {
        guard let id = UUID(uuidString: record.id) else { return nil }
        self.init(
            id: id,
            name: record.name,
            mealTypes: Self.strings(record.mealTypes).compactMap(MealSlot.init(rawValue:)),
            nutrients: Self.strings(record.nutrients).compactMap(Nutrient.init(rawValue:)),
            timeMinutes: record.timeMinutes,
            servings: record.servings,
            steps: Self.strings(record.steps),
            notes: record.notes,
            imagePath: record.imagePath,
            emoji: record.emoji,
            isFavorite: record.isFavorite
        )
    }

    /// Strings of a JSON array column; tolerant of malformed text (an empty list).
    private static func strings(_ jsonText: String) -> [String] {
        guard case .array(let values) = try? JSONValue.parse(jsonText: jsonText) else { return [] }
        return values.compactMap(\.stringValue)
    }
}

extension RecipeRecord {
    init(id: String, name: String) {
        self.init(
            id: id,
            householdId: "",
            name: name,
            mealTypes: "[]",
            nutrients: "[]",
            timeMinutes: nil,
            servings: 2,
            steps: "[]",
            notes: nil,
            imagePath: nil,
            emoji: nil,
            isFavorite: false,
            createdAt: nil,
            updatedAt: nil,
            updatedBy: nil,
            deletedAt: nil,
            clientUpdatedAt: nil,
            serverSeq: nil
        )
    }
}

extension RecipeIngredientRecord {
    init(
        id: String,
        householdId: String,
        recipeId: String,
        productId: String,
        quantity: Double?,
        unit: String?,
        position: Int
    ) {
        self.init(
            id: id,
            householdId: householdId,
            recipeId: recipeId,
            productId: productId,
            quantity: quantity,
            unit: unit,
            position: position,
            createdAt: nil,
            updatedAt: nil,
            updatedBy: nil,
            deletedAt: nil,
            clientUpdatedAt: nil,
            serverSeq: nil
        )
    }
}

extension RecipeComponentRecord {
    init(
        id: String,
        householdId: String,
        parentRecipeId: String,
        childRecipeId: String,
        servingsFactor: Double,
        position: Int
    ) {
        self.init(
            id: id,
            householdId: householdId,
            parentRecipeId: parentRecipeId,
            childRecipeId: childRecipeId,
            servingsFactor: servingsFactor,
            position: position,
            createdAt: nil,
            updatedAt: nil,
            updatedBy: nil,
            deletedAt: nil,
            clientUpdatedAt: nil,
            serverSeq: nil
        )
    }
}
