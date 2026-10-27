import Foundation
import Observation

enum AddRecipeLinkState: Sendable, Equatable {
    case editing
    case saving
    case completed
}

enum AddRecipeLinkIntent: Sendable {
    /// Text from the pasteboard ("Pegar"); `nil` when it holds no text.
    case pasted(String?)
    case submit
}

/// "Añadir vídeo": a link pasted or typed, previewed with its platform and account, added at the end of the recipe's
/// links.
@MainActor
@Observable
final class AddRecipeLinkViewModel: MVIViewModel {
    // MARK: - Properties

    let recipeID: UUID
    var text = ""
    private(set) var state = AddRecipeLinkState.editing
    var toast: Toast?

    @ObservationIgnored private let addLink: any AddRecipeLinkUseCase

    // MARK: - Lifecycle

    init(recipeID: UUID, addLink: any AddRecipeLinkUseCase) {
        self.recipeID = recipeID
        self.addLink = addLink
    }

    // MARK: - Derived

    /// The detected link, `nil` while the text holds no valid `http(s)` URL.
    var detection: RecipeLinkInfo? { RecipeLinkPlatform.detect(url: text) }
    var canSubmit: Bool { detection != nil && state == .editing }

    // MARK: - Intents

    func send(_ intent: AddRecipeLinkIntent) async {
        switch intent {
        case .pasted(let value):
            guard let value, !value.isEmpty else { return }
            // Keep only the link when the pasteboard holds a whole message.
            text = RecipeLinkPlatform.detect(url: value)?.url.absoluteString ?? value
        case .submit:
            await submit()
        }
    }

    // MARK: - Private Methods

    private func submit() async {
        guard canSubmit else { return }
        state = .saving
        do {
            try await addLink.execute(recipeID: recipeID, text: text)
            state = .completed
        } catch {
            toast = .error(error)
            state = .editing
        }
    }
}
