import Foundation
import GRDB

final class ProductPhotoRepositoryImpl: ProductPhotoRepository, Sendable {
    // MARK: - Properties

    private let database: AppDatabase
    private let writer: LocalMutationWriter
    private let fileDataSource: any RecipeImageFileDataSource

    // MARK: - Lifecycle

    init(database: AppDatabase, writer: LocalMutationWriter, fileDataSource: any RecipeImageFileDataSource) {
        self.database = database
        self.writer = writer
        self.fileDataSource = fileDataSource
    }

    // MARK: - ProductPhotoRepository

    @discardableResult
    func addPhoto(productID: UUID, image: TranscodedImage, asCover: Bool) async throws(KodaError) -> ProductPhoto {
        let writer = writer
        let fileDataSource = fileDataSource
        let productKey = productID.lowercasedString
        let photoID = LocalMutationWriter.newID()

        let record = try await database.write { db in
            guard var product = try ProductRecord.fetchOne(db, key: productKey), !product.isDeleted else {
                throw KodaError(type: .notFound, reason: "Product \(productID) not found.")
            }
            let householdID = product.householdId.isEmpty ? try writer.context(db).householdID : product.householdId
            // The bucket's policies key on the first folder: the household.
            let path = "\(householdID)/\(productKey)/\(UUID().uuidString.lowercased()).jpg"
            let position =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COALESCE(MAX(position), -1) + 1 FROM product_photos
                        WHERE product_id = ? AND deleted_at IS NULL
                        """,
                    arguments: [productKey]
                ) ?? 0

            // The file first: if the transaction fails, an orphan file is harmless; a row without its file is not.
            try fileDataSource.write(image.data, at: path, bucket: .products)
            let saved = try writer.save(
                ProductPhotoRecord(
                    id: photoID,
                    householdId: householdID,
                    productId: productKey,
                    storagePath: path,
                    width: image.width,
                    height: image.height,
                    position: position
                ),
                in: db
            )
            try db.execute(
                sql: """
                    INSERT OR IGNORE INTO pending_image_uploads (storage_path, bucket, created_at) VALUES (?, ?, ?)
                    """,
                arguments: [path, ImageBucket.products.rawValue, writer.timestamp()]
            )
            if asCover {
                product.imagePath = path
                product.imageSource = RecipeImageSource.photo.rawValue
                try writer.save(product, in: db)
            }
            return saved
        }
        guard let photo = ProductPhoto(record: record) else {
            throw KodaError(type: .internal, reason: "Invalid product photo \(record.id).")
        }
        return photo
    }

    func setCover(productID: UUID, path: String?, source: RecipeImageSource) async throws(KodaError) {
        let writer = writer
        try await database.write { db in
            guard var product = try ProductRecord.fetchOne(db, key: productID.lowercasedString) else {
                throw KodaError(type: .notFound, reason: "Product \(productID) not found.")
            }
            guard product.imagePath != path else { return }
            product.imagePath = path
            product.imageSource = path == nil ? nil : source.rawValue
            try writer.save(product, in: db)
        }
    }

    func deletePhoto(id: UUID) async throws(KodaError) {
        let writer = writer
        let removedPath = try await database.write { db -> String? in
            guard let photo = try ProductPhotoRecord.fetchOne(db, key: id.lowercasedString), !photo.isDeleted else {
                return nil
            }
            try writer.delete(.productPhotos, id: photo.id, in: db)
            try db.execute(
                sql: "DELETE FROM pending_image_uploads WHERE storage_path = ?",
                arguments: [photo.storagePath]
            )
            if var product = try ProductRecord.fetchOne(db, key: photo.productId), !product.isDeleted,
                product.imagePath == photo.storagePath
            {
                let next = try ProductPhotoRecord.live()
                    .filter(Column("product_id") == photo.productId)
                    .order(Column("position"), Column("created_at"))
                    .fetchOne(db)
                product.imagePath = next?.storagePath
                product.imageSource = next == nil ? nil : RecipeImageSource.photo.rawValue
                try writer.save(product, in: db)
            }
            return photo.storagePath
        }
        if let removedPath { fileDataSource.remove(at: removedPath, bucket: .products) }
    }
}
