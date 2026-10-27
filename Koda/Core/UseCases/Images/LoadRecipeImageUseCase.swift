import Foundation

/// The bytes of a recipe or product image (cover or gallery photo) for display or sharing.
protocol LoadRecipeImageUseCase: Sendable {
    func execute(path: String, bucket: ImageBucket) async -> Data?
    func localFileURL(path: String, bucket: ImageBucket) -> URL?
}

final class LoadRecipeImageUseCaseImpl: LoadRecipeImageUseCase, Sendable {
    private let repository: any RecipeImageRepository

    init(repository: any RecipeImageRepository) {
        self.repository = repository
    }

    func execute(path: String, bucket: ImageBucket) async -> Data? {
        await repository.imageData(path: path, bucket: bucket)
    }

    func localFileURL(path: String, bucket: ImageBucket) -> URL? {
        repository.localFileURL(path: path, bucket: bucket)
    }
}
