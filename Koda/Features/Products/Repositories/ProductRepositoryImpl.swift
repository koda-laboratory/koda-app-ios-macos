import Foundation
import GRDB

final class ProductRepositoryImpl: ProductRepository, Sendable {
    // MARK: - Properties

    private let database: AppDatabase
    private let writer: LocalMutationWriter

    // MARK: - Lifecycle

    init(database: AppDatabase, writer: LocalMutationWriter) {
        self.database = database
        self.writer = writer
    }

    // MARK: - Observation

    func observeProducts() -> AsyncStream<[Product]> {
        database.observe { db in
            let links = try ProductStoreRecord.live().fetchAll(db)
            let storesByProduct = Dictionary(grouping: links, by: \.productId)
            return try ProductRecord.live()
                .order(Column("name").collating(.localizedCaseInsensitiveCompare))
                .fetchAll(db)
                .compactMap { Product(record: $0, links: storesByProduct[$0.id] ?? []) }
        }
    }

    func observeProductDetail(id: UUID) -> AsyncStream<ProductDetail?> {
        let productID = id.lowercasedString
        return database.observe { db in try Self.fetchDetail(productID: productID, in: db) }
    }

    func observeStores() -> AsyncStream<[Store]> {
        database.observe { db in
            try StoreRecord.live()
                .order(Column("name").collating(.localizedCaseInsensitiveCompare))
                .fetchAll(db)
                .compactMap(Store.init(record:))
        }
    }

    // MARK: - Mutations

    @discardableResult
    func saveProduct(_ input: ProductInput) async throws(KodaError) -> Product {
        let writer = writer
        return try await database.write { db in
            let id = input.id?.lowercasedString ?? LocalMutationWriter.newID()
            var record =
                try ProductRecord.fetchOne(db, key: id)
                ?? ProductRecord(id: id, householdId: "", name: input.name, category: input.category.rawValue)
            record.name = input.name
            record.category = input.category.rawValue
            record.defaultUnit = input.defaultUnit
            record.pricePerKg = input.pricePerKg
            record.priceTotal = input.priceTotal
            record.servings = input.servings
            record.servingsPerWeek = input.servingsPerWeek
            record.notes = input.notes
            record.emoji = input.emoji
            let saved = try writer.save(record, in: db)

            if let storeIDs = input.storeIDs {
                try Self.replaceStores(storeIDs, of: saved.id, writer: writer, in: db)
            }
            let links = try ProductStoreRecord.live().filter(Column("product_id") == saved.id).fetchAll(db)
            guard let product = Product(record: saved, links: links) else {
                throw KodaError(type: .internal, reason: "Invalid product \(saved.id).")
            }
            return product
        }
    }

    func deleteProduct(id: UUID) async throws(KodaError) {
        let writer = writer
        try await database.write { db in try writer.delete(.products, id: id.lowercasedString, in: db) }
    }

    @discardableResult
    func saveStore(_ input: StoreInput) async throws(KodaError) -> Store {
        let writer = writer
        return try await database.write { db in
            let id = input.id?.lowercasedString ?? LocalMutationWriter.newID()
            var record = try StoreRecord.fetchOne(db, key: id) ?? StoreRecord(id: id, householdId: "", name: input.name)
            record.name = input.name
            record.color = input.color
            let saved = try writer.save(record, in: db)
            guard let store = Store(record: saved) else {
                throw KodaError(type: .internal, reason: "Invalid store \(saved.id).")
            }
            return store
        }
    }

    func deleteStore(id: UUID) async throws(KodaError) {
        let writer = writer
        try await database.write { db in try writer.delete(.stores, id: id.lowercasedString, in: db) }
    }

    // MARK: - Private Methods

    private static func fetchDetail(productID: String, in db: Database) throws -> ProductDetail? {
        guard let record = try ProductRecord.live().filter(key: productID).fetchOne(db) else { return nil }
        let links = try ProductStoreRecord.live().filter(Column("product_id") == productID).fetchAll(db)
        guard let product = Product(record: record, links: links) else { return nil }

        let stores = try StoreRecord.live()
            .filter(keys: links.map(\.storeId))
            .order(Column("name").collating(.localizedCaseInsensitiveCompare))
            .fetchAll(db)
            .compactMap(Store.init(record:))
        let photos = try ProductPhotoRecord.live()
            .filter(Column("product_id") == productID)
            .order(Column("position"), Column("created_at"))
            .fetchAll(db)
            .compactMap(ProductPhoto.init(record:))
        // One row per recipe: the first ingredient line that uses the product.
        let usageRows = try Row.fetchAll(
            db,
            sql: """
                SELECT r.id, r.name, r.time_minutes, i.quantity, i.unit
                FROM recipe_ingredients i
                JOIN recipes r ON r.id = i.recipe_id AND r.deleted_at IS NULL
                WHERE i.product_id = ? AND i.deleted_at IS NULL
                ORDER BY r.name COLLATE NOCASE, i.position
                """,
            arguments: [productID]
        )
        var seen = Set<UUID>()
        let usages = usageRows.compactMap { row -> ProductRecipeUsage? in
            guard let recipeID = UUID(uuidString: row["id"]), seen.insert(recipeID).inserted else { return nil }
            return ProductRecipeUsage(
                recipeID: recipeID,
                recipeName: row["name"],
                quantity: row["quantity"],
                unit: row["unit"],
                timeMinutes: row["time_minutes"]
            )
        }
        return ProductDetail(product: product, stores: stores, photos: photos, usages: usages)
    }

    private static func replaceStores(
        _ storeIDs: Set<UUID>,
        of productID: String,
        writer: LocalMutationWriter,
        in db: Database
    ) throws {
        let wanted = Set(storeIDs.map(\.lowercasedString))
        let links = try ProductStoreRecord.live().filter(Column("product_id") == productID).fetchAll(db)
        for link in links where !wanted.contains(link.storeId) {
            try writer.delete(.productStores, id: link.id, in: db)
        }
        let existing = Set(links.map(\.storeId))
        for storeID in wanted.subtracting(existing).sorted() {
            try writer.save(
                ProductStoreRecord(
                    id: LocalMutationWriter.newID(),
                    householdId: "",
                    productId: productID,
                    storeId: storeID
                ),
                in: db
            )
        }
    }
}

// MARK: - Mapping

extension Product {
    init?(record: ProductRecord, links: [ProductStoreRecord]) {
        guard let id = UUID(uuidString: record.id) else { return nil }
        self.init(
            id: id,
            name: record.name,
            category: ProductCategory(rawValue: record.category) ?? .food,
            defaultUnit: record.defaultUnit,
            pricePerKg: record.pricePerKg,
            priceTotal: record.priceTotal,
            servings: record.servings,
            servingsPerWeek: record.servingsPerWeek,
            notes: record.notes,
            emoji: record.emoji,
            imagePath: record.imagePath,
            imageSource: record.imageSource.flatMap(RecipeImageSource.init(rawValue:)),
            storeIDs: Set(links.compactMap { UUID(uuidString: $0.storeId) })
        )
    }
}

extension ProductPhoto {
    init?(record: ProductPhotoRecord) {
        guard let id = UUID(uuidString: record.id), let productID = UUID(uuidString: record.productId) else {
            return nil
        }
        self.init(
            id: id,
            productID: productID,
            storagePath: record.storagePath,
            width: record.width,
            height: record.height,
            position: record.position
        )
    }
}

extension Store {
    init?(record: StoreRecord) {
        guard let id = UUID(uuidString: record.id) else { return nil }
        self.init(id: id, name: record.name, color: record.color)
    }
}

extension ProductRecord {
    init(id: String, householdId: String, name: String, category: String) {
        self.init(
            id: id,
            householdId: householdId,
            name: name,
            category: category,
            defaultUnit: nil,
            pricePerKg: nil,
            priceTotal: nil,
            servings: nil,
            servingsPerWeek: nil,
            notes: nil,
            emoji: nil,
            createdAt: nil,
            updatedAt: nil,
            updatedBy: nil,
            deletedAt: nil,
            clientUpdatedAt: nil,
            serverSeq: nil
        )
    }
}

extension StoreRecord {
    init(id: String, householdId: String, name: String) {
        self.init(
            id: id,
            householdId: householdId,
            name: name,
            color: nil,
            createdAt: nil,
            updatedAt: nil,
            updatedBy: nil,
            deletedAt: nil,
            clientUpdatedAt: nil,
            serverSeq: nil
        )
    }
}

extension ProductStoreRecord {
    init(id: String, householdId: String, productId: String, storeId: String) {
        self.init(
            id: id,
            householdId: householdId,
            productId: productId,
            storeId: storeId,
            createdAt: nil,
            updatedAt: nil,
            updatedBy: nil,
            deletedAt: nil,
            clientUpdatedAt: nil,
            serverSeq: nil
        )
    }
}
