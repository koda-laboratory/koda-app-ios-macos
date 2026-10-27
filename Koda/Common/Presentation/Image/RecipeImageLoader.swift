import CoreGraphics
import Foundation
import Synchronization
import SwiftUI

/// Loads recipe and product images for display: decoded, downsampled `CGImage`s kept in a small memory cache in front of the
/// on-disk cache. Installed once at the root (`.environment(\.recipeImageLoader, …)`) so tiles, the hero and the
/// gallery share it without a ViewModel per image.
struct RecipeImageLoader: Sendable {
    let image: @Sendable (_ path: String, _ bucket: ImageBucket, _ maxPixelSize: Int) async -> CGImage?
    /// The file of an image already on disk, for sharing.
    let fileURL: @Sendable (_ path: String, _ bucket: ImageBucket) -> URL?

    static let unavailable = RecipeImageLoader(image: { _, _, _ in nil }, fileURL: { _, _ in nil })

    static func live(useCase: any LoadRecipeImageUseCase) -> RecipeImageLoader {
        let cache = RecipeImageMemoryCache()
        return RecipeImageLoader(
            image: { path, bucket, maxPixelSize in
                let key = "\(bucket.rawValue)|\(maxPixelSize)|\(path)"
                if let cached = cache.image(for: key) { return cached }
                guard let data = await useCase.execute(path: path, bucket: bucket),
                    let image = ImageDecoding.thumbnail(from: data, maxPixelSize: maxPixelSize)
                else { return nil }
                cache.insert(image, for: key)
                return image
            },
            fileURL: { useCase.localFileURL(path: $0, bucket: $1) }
        )
    }
}

extension EnvironmentValues {
    @Entry var recipeImageLoader = RecipeImageLoader.unavailable
}

/// Decoded images by path and size, dropped wholesale past a limit (a few screens of tiles).
private final class RecipeImageMemoryCache: Sendable {
    private static let limit = 80
    private let storage = Mutex<[String: CGImage]>([:])

    func image(for key: String) -> CGImage? {
        storage.withLock { $0[key] }
    }

    func insert(_ image: CGImage, for key: String) {
        storage.withLock { images in
            if images.count >= Self.limit { images.removeAll(keepingCapacity: true) }
            images[key] = image
        }
    }
}
