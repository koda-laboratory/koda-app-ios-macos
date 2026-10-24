import Foundation

/// "Hacer foto" / "Elegir de la galería": re-encodes the picked image (JPEG, 1600 px on the longest side) and adds
/// it to the gallery, optionally as the cover. It uploads by itself when there is a connection.
protocol AddRecipePhotoUseCase: Sendable {
    func execute(recipeID: UUID, imageData: Data, asCover: Bool) async throws(KodaError)
}

final class AddRecipePhotoUseCaseImpl: AddRecipePhotoUseCase, Sendable {
    static let maxPixelSize = 1600
    static let quality = 0.8

    private let repository: any RecipePhotoRepository
    private let transcoder: any ImageTranscoding

    init(repository: any RecipePhotoRepository, transcoder: any ImageTranscoding) {
        self.repository = repository
        self.transcoder = transcoder
    }

    func execute(recipeID: UUID, imageData: Data, asCover: Bool) async throws(KodaError) {
        // Nonisolated async: the decoding runs off the main actor.
        guard let image = transcoder.jpeg(from: imageData, maxPixelSize: Self.maxPixelSize, quality: Self.quality)
        else {
            throw KodaError(type: .badRequest, reason: "The selected file is not an image Koda can read.")
        }
        try await repository.addPhoto(recipeID: recipeID, image: image, asCover: asCover)
    }
}

/// "Usar como portada" (a gallery photo or the existing cover) and removing the cover.
protocol SetRecipeCoverUseCase: Sendable {
    func execute(recipeID: UUID, item: RecipeGalleryItem?) async throws(KodaError)
}

final class SetRecipeCoverUseCaseImpl: SetRecipeCoverUseCase, Sendable {
    private let repository: any RecipePhotoRepository

    init(repository: any RecipePhotoRepository) {
        self.repository = repository
    }

    func execute(recipeID: UUID, item: RecipeGalleryItem?) async throws(KodaError) {
        try await repository.setCover(recipeID: recipeID, path: item?.path, source: .photo)
    }
}

/// "Eliminar": a gallery photo, or the cover when it is not part of the gallery.
protocol DeleteRecipePhotoUseCase: Sendable {
    func execute(recipeID: UUID, item: RecipeGalleryItem) async throws(KodaError)
}

final class DeleteRecipePhotoUseCaseImpl: DeleteRecipePhotoUseCase, Sendable {
    private let repository: any RecipePhotoRepository

    init(repository: any RecipePhotoRepository) {
        self.repository = repository
    }

    func execute(recipeID: UUID, item: RecipeGalleryItem) async throws(KodaError) {
        if let photoID = item.photoID {
            try await repository.deletePhoto(id: photoID)
        } else if item.isCover {
            try await repository.setCover(recipeID: recipeID, path: nil, source: .photo)
        }
    }
}
