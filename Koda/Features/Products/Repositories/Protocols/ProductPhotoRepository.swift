import Foundation

/// The gallery and the cover of a product (local-first: the image file on disk, the rows and their outbox entries,
/// and the image queued for upload to `product-images`, in one step).
protocol ProductPhotoRepository: Sendable {
    /// Stores the image, adds it at the end of the gallery and, with `asCover`, makes it the cover.
    @discardableResult
    func addPhoto(productID: UUID, image: TranscodedImage, asCover: Bool) async throws(KodaError) -> ProductPhoto
    /// `nil` removes the cover.
    func setCover(productID: UUID, path: String?, source: RecipeImageSource) async throws(KodaError)
    /// Tombstones the photo; when it was the cover, the next photo of the gallery (or none) takes its place.
    func deletePhoto(id: UUID) async throws(KodaError)
}
