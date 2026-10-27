import Foundation

/// "Vídeos": the links of a recipe, in order.
protocol ObserveRecipeLinksUseCase: Sendable {
    func execute(recipeID: UUID) -> AsyncStream<[RecipeLink]>
}

final class ObserveRecipeLinksUseCaseImpl: ObserveRecipeLinksUseCase, Sendable {
    private let repository: any RecipeLinkRepository

    init(repository: any RecipeLinkRepository) {
        self.repository = repository
    }

    func execute(recipeID: UUID) -> AsyncStream<[RecipeLink]> {
        repository.observeLinks(recipeID: recipeID)
    }
}

/// "Añadir vídeo": keeps only the `http(s)` link of what was pasted (surrounding text is dropped) and adds it at the
/// end of the recipe's links.
protocol AddRecipeLinkUseCase: Sendable {
    func execute(recipeID: UUID, text: String) async throws(KodaError)
}

final class AddRecipeLinkUseCaseImpl: AddRecipeLinkUseCase, Sendable {
    private let repository: any RecipeLinkRepository

    init(repository: any RecipeLinkRepository) {
        self.repository = repository
    }

    func execute(recipeID: UUID, text: String) async throws(KodaError) {
        guard let info = RecipeLinkPlatform.detect(url: text) else {
            throw KodaError(type: .badRequest, reason: "A recipe link needs an http(s) URL.")
        }
        try await repository.addLink(recipeID: recipeID, url: info.url)
    }
}

/// "Quitar" a link.
protocol RemoveRecipeLinkUseCase: Sendable {
    func execute(linkID: UUID) async throws(KodaError)
}

final class RemoveRecipeLinkUseCaseImpl: RemoveRecipeLinkUseCase, Sendable {
    private let repository: any RecipeLinkRepository

    init(repository: any RecipeLinkRepository) {
        self.repository = repository
    }

    func execute(linkID: UUID) async throws(KodaError) {
        try await repository.removeLink(id: linkID)
    }
}
