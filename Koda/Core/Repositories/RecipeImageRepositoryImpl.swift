import Foundation
import GRDB

final class RecipeImageRepositoryImpl: RecipeImageRepository, Sendable {
    // MARK: - Properties

    private let database: AppDatabase
    private let fileDataSource: any RecipeImageFileDataSource
    private let remoteDataSource: any RecipeImageRemoteDataSource

    // MARK: - Lifecycle

    init(
        database: AppDatabase,
        fileDataSource: any RecipeImageFileDataSource,
        remoteDataSource: any RecipeImageRemoteDataSource
    ) {
        self.database = database
        self.fileDataSource = fileDataSource
        self.remoteDataSource = remoteDataSource
    }

    // MARK: - Reading

    func imageData(path: String, bucket: ImageBucket) async -> Data? {
        if let data = fileDataSource.data(at: path, bucket: bucket) { return data }
        guard let data = try? await remoteDataSource.download(path: path, bucket: bucket), !data.isEmpty else {
            return nil
        }
        try? fileDataSource.write(data, at: path, bucket: bucket)
        return data
    }

    func localFileURL(path: String, bucket: ImageBucket) -> URL? {
        fileDataSource.fileURL(at: path, bucket: bucket)
    }

    // MARK: - Uploads

    func observePendingUploads() -> AsyncStream<[PendingImageUpload]> {
        database.observe { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT storage_path, bucket, attempts FROM pending_image_uploads
                    ORDER BY created_at, storage_path
                    """
            )
            .compactMap { row in
                // A bucket unknown to this version stays queued for a newer one.
                guard let bucket = ImageBucket(rawValue: row["bucket"]) else { return nil }
                return PendingImageUpload(path: row["storage_path"], bucket: bucket, attempts: row["attempts"])
            }
        }
    }

    func upload(path: String) async throws(KodaError) {
        // Idempotent: the queue observation can briefly hand back a path that was just uploaded.
        let bucketName = try await database.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT bucket FROM pending_image_uploads WHERE storage_path = ?",
                arguments: [path]
            )
        }
        guard let bucketName, let bucket = ImageBucket(rawValue: bucketName) else { return }
        if let data = fileDataSource.data(at: path, bucket: bucket) {
            try await remoteDataSource.upload(
                data,
                path: path,
                bucket: bucket,
                contentType: Self.contentType(of: path)
            )
        }
        try await database.write { db in
            try db.execute(sql: "DELETE FROM pending_image_uploads WHERE storage_path = ?", arguments: [path])
        }
    }

    func recordUploadFailure(path: String, error: KodaError) async {
        try? await database.write { db in
            try db.execute(
                sql: """
                    UPDATE pending_image_uploads SET attempts = attempts + 1, last_error = ?
                    WHERE storage_path = ?
                    """,
                arguments: [error.type.rawValue, path]
            )
        }
    }

    func removeAllLocalImages() {
        fileDataSource.removeAll()
    }

    // MARK: - Private Methods

    private static func contentType(of path: String) -> String {
        switch path.split(separator: ".").last?.lowercased() {
        case "png": "image/png"
        case "webp": "image/webp"
        default: "image/jpeg"
        }
    }
}
