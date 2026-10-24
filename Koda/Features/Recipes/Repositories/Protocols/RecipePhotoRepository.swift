import Foundation

/// The gallery and the cover of a recipe (local-first: the image file on disk, the rows and their outbox entries,
/// and the image queued for upload, in one step).
protocol RecipePhotoRepository: Sendable {
    /// Stores the image, adds it at the end of the gallery and, with `asCover`, makes it the cover.
    @discardableResult
    func addPhoto(recipeID: UUID, image: TranscodedImage, asCover: Bool) async throws(KodaError) -> RecipePhoto
    /// `nil` removes the cover.
    func setCover(recipeID: UUID, path: String?, source: RecipeImageSource) async throws(KodaError)
    /// Tombstones the photo; when it was the cover, the next photo of the gallery (or none) takes its place.
    func deletePhoto(id: UUID) async throws(KodaError)
}
