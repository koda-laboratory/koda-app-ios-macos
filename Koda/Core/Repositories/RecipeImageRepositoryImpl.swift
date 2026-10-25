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

    func imageData(path: String) async -> Data? {
        if let data = fileDataSource.data(at: path) { return data }
        guard let data = try? await remoteDataSource.download(path: path), !data.isEmpty else { return nil }
        try? fileDataSource.write(data, at: path)
        return data
    }

    func localFileURL(path: String) -> URL? {
        fileDataSource.fileURL(at: path)
    }

    // MARK: - Uploads

    func observePendingUploads() -> AsyncStream<[PendingImageUpload]> {
        database.observe { db in
            try Row.fetchAll(
                db,
                sql: "SELECT storage_path, attempts FROM pending_image_uploads ORDER BY created_at, storage_path"
            )
            .map { PendingImageUpload(path: $0["storage_path"], attempts: $0["attempts"]) }
        }
    }

    func upload(path: String) async throws(KodaError) {
        // Idempotent: the queue observation can briefly hand back a path that was just uploaded.
        let isPending = try await database.read { db in
            try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM pending_image_uploads WHERE storage_path = ?)",
                arguments: [path]
            ) ?? false
        }
        guard isPending else { return }
        if let data = fileDataSource.data(at: path) {
            try await remoteDataSource.upload(data, path: path, contentType: Self.contentType(of: path))
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
