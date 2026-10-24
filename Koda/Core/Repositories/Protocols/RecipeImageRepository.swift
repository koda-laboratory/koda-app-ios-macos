import Foundation

/// Recipe image bytes: the on-disk cache, downloads from Storage and the queue of photos to upload.
protocol RecipeImageRepository: Sendable {
    /// The image at a Storage path: from disk, or downloaded once and kept. `nil` while it does not exist yet (for
    /// example a partner's photo that their device has not uploaded) or offline.
    func imageData(path: String) async -> Data?
    /// The file of an image already on disk (sharing).
    func localFileURL(path: String) -> URL?
    /// Storage paths waiting to be uploaded, the oldest first; emits on every change.
    func observePendingUploads() -> AsyncStream<[PendingImageUpload]>
    /// Uploads one pending image and removes it from the queue (a lost local file is dropped from the queue).
    func upload(path: String) async throws(KodaError)
    func recordUploadFailure(path: String, error: KodaError) async
    /// Sign-out: every image file on disk.
    func removeAllLocalImages()
}

struct PendingImageUpload: Sendable, Equatable {
    let path: String
    let attempts: Int
}
