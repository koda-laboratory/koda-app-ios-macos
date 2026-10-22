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
            storeIDs: Set(links.compactMap { UUID(uuidString: $0.storeId) })
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
