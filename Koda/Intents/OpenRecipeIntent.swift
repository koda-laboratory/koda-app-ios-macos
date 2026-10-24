import AppIntents
import Foundation

/// Opens a recipe from Spotlight or Shortcuts.
struct OpenRecipeIntent: OpenIntent {
    static let title: LocalizedStringResource = "intent.open-recipe.title"
    static var supportedModes: IntentModes { .foreground }

    @Parameter(title: "intent.recipe.type")
    var target: RecipeEntity

    init() {}

    init(target: RecipeEntity) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let router = IntentNavigator.shared.router else { return .result() }
        router.open(.recipe(id: target.id))
        return .result()
    }
}
