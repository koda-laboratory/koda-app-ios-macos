import Foundation

/// The product detail: the product, its stores, its gallery and the recipes that use it; `nil` once deleted.
protocol ObserveProductDetailUseCase: Sendable {
    func execute(productID: UUID) -> AsyncStream<ProductDetail?>
}

final class ObserveProductDetailUseCaseImpl: ObserveProductDetailUseCase, Sendable {
    private let repository: any ProductRepository

    init(repository: any ProductRepository) {
        self.repository = repository
    }

    func execute(productID: UUID) -> AsyncStream<ProductDetail?> {
        repository.observeProductDetail(id: productID)
    }
}

/// "Hacer foto" / "Elegir de la galería" on a product: re-encodes the picked image (JPEG, 1600 px on the longest
/// side) and adds it to the gallery, optionally as the cover. It uploads to `product-images` by itself when there is a
/// connection.
protocol AddProductPhotoUseCase: Sendable {
    func execute(productID: UUID, imageData: Data, asCover: Bool) async throws(KodaError)
}

final class AddProductPhotoUseCaseImpl: AddProductPhotoUseCase, Sendable {
    static let maxPixelSize = 1600
    static let quality = 0.8

    private let repository: any ProductPhotoRepository
    private let transcoder: any ImageTranscoding

    init(repository: any ProductPhotoRepository, transcoder: any ImageTranscoding) {
        self.repository = repository
        self.transcoder = transcoder
    }

    func execute(productID: UUID, imageData: Data, asCover: Bool) async throws(KodaError) {
        guard let image = transcoder.jpeg(from: imageData, maxPixelSize: Self.maxPixelSize, quality: Self.quality)
        else {
            throw KodaError(type: .badRequest, reason: "The selected file is not an image Koda can read.")
        }
        try await repository.addPhoto(productID: productID, image: image, asCover: asCover)
    }
}

/// "Usar como portada" on a product photo (or the existing cover) and removing the cover.
protocol SetProductCoverUseCase: Sendable {
    func execute(productID: UUID, item: RecipeGalleryItem?) async throws(KodaError)
}

final class SetProductCoverUseCaseImpl: SetProductCoverUseCase, Sendable {
    private let repository: any ProductPhotoRepository

    init(repository: any ProductPhotoRepository) {
        self.repository = repository
    }

    func execute(productID: UUID, item: RecipeGalleryItem?) async throws(KodaError) {
        try await repository.setCover(productID: productID, path: item?.path, source: .photo)
    }
}

/// "Eliminar" a product photo, or the cover when it is not part of the gallery.
protocol DeleteProductPhotoUseCase: Sendable {
    func execute(productID: UUID, item: RecipeGalleryItem) async throws(KodaError)
}

final class DeleteProductPhotoUseCaseImpl: DeleteProductPhotoUseCase, Sendable {
    private let repository: any ProductPhotoRepository

    init(repository: any ProductPhotoRepository) {
        self.repository = repository
    }

    func execute(productID: UUID, item: RecipeGalleryItem) async throws(KodaError) {
        if let photoID = item.photoID {
            try await repository.deletePhoto(id: photoID)
        } else if item.isCover {
            try await repository.setCover(productID: productID, path: nil, source: .photo)
        }
    }
}
