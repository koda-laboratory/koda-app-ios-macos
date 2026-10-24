import Foundation
import GRDB

final class RecipePhotoRepositoryImpl: RecipePhotoRepository, Sendable {
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

    // MARK: - RecipePhotoRepository

    @discardableResult
    func addPhoto(recipeID: UUID, image: TranscodedImage, asCover: Bool) async throws(KodaError) -> RecipePhoto {
        let writer = writer
        let fileDataSource = fileDataSource
        let recipeKey = recipeID.lowercasedString
        let photoID = LocalMutationWriter.newID()

        let record = try await database.write { db in
            guard var recipe = try RecipeRecord.fetchOne(db, key: recipeKey), !recipe.isDeleted else {
                throw KodaError(type: .notFound, reason: "Recipe \(recipeID) not found.")
            }
            let householdID = recipe.householdId.isEmpty ? try writer.context(db).householdID : recipe.householdId
            // The bucket's policies key on the first folder: the household.
            let path = "\(householdID)/\(recipeKey)/\(UUID().uuidString.lowercased()).jpg"
            let position =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COALESCE(MAX(position), -1) + 1 FROM recipe_photos
                        WHERE recipe_id = ? AND deleted_at IS NULL
                        """,
                    arguments: [recipeKey]
                ) ?? 0

            // The file first: if the transaction fails, an orphan file is harmless; a row without its file is not.
            try fileDataSource.write(image.data, at: path)
            let saved = try writer.save(
                RecipePhotoRecord(
                    id: photoID,
                    householdId: householdID,
                    recipeId: recipeKey,
                    storagePath: path,
                    width: image.width,
                    height: image.height,
                    position: position
                ),
                in: db
            )
            try db.execute(
                sql: "INSERT OR IGNORE INTO pending_image_uploads (storage_path, created_at) VALUES (?, ?)",
                arguments: [path, writer.timestamp()]
            )
            if asCover {
                recipe.imagePath = path
                recipe.imageSource = RecipeImageSource.photo.rawValue
                try writer.save(recipe, in: db)
            }
            return saved
        }
        guard let photo = RecipePhoto(record: record) else {
            throw KodaError(type: .internal, reason: "Invalid recipe photo \(record.id).")
        }
        return photo
    }

    func setCover(recipeID: UUID, path: String?, source: RecipeImageSource) async throws(KodaError) {
        let writer = writer
        try await database.write { db in
            guard var recipe = try RecipeRecord.fetchOne(db, key: recipeID.lowercasedString) else {
                throw KodaError(type: .notFound, reason: "Recipe \(recipeID) not found.")
            }
            guard recipe.imagePath != path else { return }
            recipe.imagePath = path
            recipe.imageSource = path == nil ? nil : source.rawValue
            try writer.save(recipe, in: db)
        }
    }

    func deletePhoto(id: UUID) async throws(KodaError) {
        let writer = writer
        let fileDataSource = fileDataSource
        let removedPath = try await database.write { db -> String? in
            guard let photo = try RecipePhotoRecord.fetchOne(db, key: id.lowercasedString), !photo.isDeleted else {
                return nil
            }
            try writer.delete(.recipePhotos, id: photo.id, in: db)
            try db.execute(
                sql: "DELETE FROM pending_image_uploads WHERE storage_path = ?",
                arguments: [photo.storagePath]
            )
            if var recipe = try RecipeRecord.fetchOne(db, key: photo.recipeId), !recipe.isDeleted,
                recipe.imagePath == photo.storagePath
            {
                let next = try RecipePhotoRecord.live()
                    .filter(Column("recipe_id") == photo.recipeId)
                    .order(Column("position"), Column("created_at"))
                    .fetchOne(db)
                recipe.imagePath = next?.storagePath
                recipe.imageSource = next == nil ? nil : RecipeImageSource.photo.rawValue
                try writer.save(recipe, in: db)
            }
            return photo.storagePath
        }
        if let removedPath { fileDataSource.remove(at: removedPath) }
    }
}
