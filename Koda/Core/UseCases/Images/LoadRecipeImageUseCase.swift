import Foundation

/// The bytes of a recipe image (cover or gallery photo) for display or sharing.
protocol LoadRecipeImageUseCase: Sendable {
    func execute(path: String) async -> Data?
    func localFileURL(path: String) -> URL?
}

final class LoadRecipeImageUseCaseImpl: LoadRecipeImageUseCase, Sendable {
    private let repository: any RecipeImageRepository

    init(repository: any RecipeImageRepository) {
        self.repository = repository
    }

    func execute(path: String) async -> Data? {
        await repository.imageData(path: path)
    }

    func localFileURL(path: String) -> URL? {
        repository.localFileURL(path: path)
    }
}
