import Foundation
import GRDB

final class ShoppingRepositoryImpl: ShoppingRepository, Sendable {
    // MARK: - Properties

    private let database: AppDatabase
    private let writer: LocalMutationWriter

    // MARK: - Lifecycle

    init(database: AppDatabase, writer: LocalMutationWriter) {
        self.database = database
        self.writer = writer
    }

    // MARK: - Observation

    func observeEntries() -> AsyncStream<[ShoppingEntry]> {
        database.observe { db in try Self.fetchEntries(in: db) }
    }

    // MARK: - Mutations

    @discardableResult
    func addEntry(_ input: NewShoppingEntry) async throws(KodaError) -> ShoppingEntry {
        let writer = writer
        return try await database.write { db in
            var record = ShoppingEntryRecord.new(kind: .product, position: try Self.nextPosition(in: db))
            switch input.item {
            case .product(let productID):
                record.productId = productID.lowercasedString
            case .text(let text):
                record.kind = ShoppingEntryKind.text.rawValue
                record.text = text
            }
            record.quantity = input.quantity
            record.unit = input.unit
            record.source = input.source.rawValue
            let saved = try writer.save(record, in: db)
            return try Self.fetchEntry(id: saved.id, in: db)
        }
    }

    @discardableResult
    func addRecipeEntry(_ input: NewRecipeShoppingEntry) async throws(KodaError) -> ShoppingEntry {
        let writer = writer
        return try await database.write { db in
            var record = ShoppingEntryRecord.new(kind: .recipe, position: try Self.nextPosition(in: db))
            record.recipeId = input.recipeID.lowercasedString
            record.text = input.label
            record.quantity = input.servings
            // Same convention as the backend's `shopping_from_plan`.
            record.unit = input.servings == nil ? nil : "servings"
            record.source = input.source.rawValue
            record.mealPlanEntryId = input.mealPlanEntryID?.lowercasedString
            let entry = try writer.save(record, in: db)

            for item in input.items {
                try writer.save(
                    ShoppingEntryItemRecord(
                        id: LocalMutationWriter.newID(),
                        householdId: "",
                        entryId: entry.id,
                        productId: item.productID.lowercasedString,
                        quantity: item.quantity,
                        unit: item.unit,
                        checked: false,
                        checkedAt: nil,
                        createdAt: nil,
                        updatedAt: nil,
                        updatedBy: nil,
                        deletedAt: nil,
                        clientUpdatedAt: nil,
                        serverSeq: nil
                    ),
                    in: db
                )
            }
            return try Self.fetchEntry(id: entry.id, in: db)
        }
    }

    func setEntryChecked(id: UUID, isChecked: Bool) async throws(KodaError) {
        let writer = writer
        try await database.write { db in
            var record = try Self.liveEntry(id: id.lowercasedString, in: db)
            if record.checked != isChecked {
                record.checked = isChecked
                try writer.save(record, in: db)
            }
            guard record.kind == ShoppingEntryKind.recipe.rawValue else { return }
            let items = try ShoppingEntryItemRecord.live()
                .filter(Column("entry_id") == record.id && Column("checked") == !isChecked)
                .fetchAll(db)
            for var item in items {
                item.checked = isChecked
                try writer.save(item, in: db)
            }
        }
    }

    func setItemChecked(id: UUID, isChecked: Bool) async throws(KodaError) {
        let writer = writer
        try await database.write { db in
            guard var item = try ShoppingEntryItemRecord.live().filter(key: id.lowercasedString).fetchOne(db) else {
                throw KodaError(type: .notFound, reason: "Shopping item \(id) not found.")
            }
            guard item.checked != isChecked else { return }
            item.checked = isChecked
            try writer.save(item, in: db)
        }
    }

    func updateEntry(id: UUID, text: String?, quantity: Double?, unit: String?) async throws(KodaError) {
        let writer = writer
        try await database.write { db in
            var record = try Self.liveEntry(id: id.lowercasedString, in: db)
            record.text = text ?? record.text
            record.quantity = quantity
            record.unit = unit
            try writer.save(record, in: db)
        }
    }

    func removeEntry(id: UUID) async throws(KodaError) {
        let writer = writer
        try await database.write { db in try writer.delete(.shoppingEntries, id: id.lowercasedString, in: db) }
    }

    @discardableResult
    func removeCheckedEntries() async throws(KodaError) -> Int {
        let writer = writer
        return try await database.write { db in
            let ids = try String.fetchAll(
                db,
                sql: "SELECT id FROM shopping_entries WHERE deleted_at IS NULL AND checked = 1"
            )
            for id in ids {
                try writer.delete(.shoppingEntries, id: id, in: db)
            }
            return ids.count
        }
    }

    // MARK: - Queries

    private static func nextPosition(in db: Database) throws -> Int {
        try Int.fetchOne(
            db,
            sql: "SELECT COALESCE(MAX(position), -1) + 1 FROM shopping_entries WHERE deleted_at IS NULL"
        )
            ?? 0
    }

    private static func liveEntry(id: String, in db: Database) throws -> ShoppingEntryRecord {
        guard let record = try ShoppingEntryRecord.live().filter(key: id).fetchOne(db) else {
            throw KodaError(type: .notFound, reason: "Shopping entry \(id) not found.")
        }
        return record
    }

    private static func fetchEntry(id: String, in db: Database) throws -> ShoppingEntry {
        guard let entry = try fetchEntries(in: db, onlyID: id).first else {
            throw KodaError(type: .internal, reason: "Shopping entry \(id) could not be read back.")
        }
        return entry
    }

    private static func fetchEntries(in db: Database, onlyID: String? = nil) throws -> [ShoppingEntry] {
        let filter = onlyID == nil ? "" : " AND s.id = ?"
        let arguments: StatementArguments = onlyID.map { [$0] } ?? []
        let entryRows = try Row.fetchAll(
            db,
            sql: """
                SELECT s.id, s.kind, s.product_id, s.recipe_id, s.text, s.quantity, s.unit, s.checked, s.source,
                       s.position, s.meal_plan_entry_id,
                       p.name AS product_name, p.emoji AS product_emoji, p.category AS product_category,
                       r.name AS recipe_name, r.emoji AS recipe_emoji
                FROM shopping_entries s
                LEFT JOIN products p ON p.id = s.product_id
                LEFT JOIN recipes r ON r.id = s.recipe_id
                WHERE s.deleted_at IS NULL\(filter)
                ORDER BY s.position
                """,
            arguments: arguments
        )

        let itemRows = try Row.fetchAll(
            db,
            sql: """
                SELECT i.id, i.entry_id, i.product_id, i.quantity, i.unit, i.checked,
                       p.name AS product_name, p.emoji AS product_emoji, p.category AS product_category
                FROM shopping_entry_items i
                LEFT JOIN products p ON p.id = i.product_id
                WHERE i.deleted_at IS NULL\(onlyID == nil ? "" : " AND i.entry_id = ?")
                ORDER BY p.name COLLATE NOCASE
                """,
            arguments: arguments
        )
        var itemsByEntry: [String: [ShoppingEntryItem]] = [:]
        for row in itemRows {
            guard let item = ShoppingEntryItem(row: row) else { continue }
            itemsByEntry[row["entry_id"], default: []].append(item)
        }

        return entryRows.compactMap { row in
            ShoppingEntry(row: row, items: itemsByEntry[row["id"]] ?? [])
        }
    }
}

// MARK: - Mapping

extension ShoppingEntry {
    init?(row: Row, items: [ShoppingEntryItem]) {
        guard let id = UUID(uuidString: row["id"]), let kind = ShoppingEntryKind(rawValue: row["kind"]) else {
            return nil
        }
        let text: String? = row["text"]
        let title: String =
            switch kind {
            case .product: row["product_name"] ?? text ?? ""
            case .recipe: text ?? row["recipe_name"] ?? ""
            case .text: text ?? ""
            }
        self.init(
            id: id,
            kind: kind,
            productID: (row["product_id"] as String?).flatMap(UUID.init(uuidString:)),
            recipeID: (row["recipe_id"] as String?).flatMap(UUID.init(uuidString:)),
            title: title,
            emoji: kind == .recipe ? row["recipe_emoji"] : row["product_emoji"],
            category: (row["product_category"] as String?).flatMap(ProductCategory.init(rawValue:)),
            quantity: row["quantity"],
            unit: row["unit"],
            isChecked: row["checked"],
            source: ShoppingEntrySource(rawValue: row["source"]) ?? .manual,
            position: row["position"],
            mealPlanEntryID: (row["meal_plan_entry_id"] as String?).flatMap(UUID.init(uuidString:)),
            items: items
        )
    }
}

extension ShoppingEntryItem {
    init?(row: Row) {
        guard let id = UUID(uuidString: row["id"]), let productID = UUID(uuidString: row["product_id"]) else {
            return nil
        }
        self.init(
            id: id,
            productID: productID,
            productName: row["product_name"] ?? "",
            productEmoji: row["product_emoji"],
            category: (row["product_category"] as String?).flatMap(ProductCategory.init(rawValue:)),
            quantity: row["quantity"],
            unit: row["unit"],
            isChecked: row["checked"]
        )
    }
}

extension ShoppingEntryRecord {
    static func new(kind: ShoppingEntryKind, position: Int) -> ShoppingEntryRecord {
        ShoppingEntryRecord(
            id: LocalMutationWriter.newID(),
            householdId: "",
            kind: kind.rawValue,
            productId: nil,
            recipeId: nil,
            text: nil,
            quantity: nil,
            unit: nil,
            checked: false,
            checkedAt: nil,
            checkedBy: nil,
            nameUpdatedAt: nil,
            source: ShoppingEntrySource.manual.rawValue,
            mealPlanEntryId: nil,
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
