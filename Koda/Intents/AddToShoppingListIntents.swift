import AppIntents
import Foundation

/// "Apunta leche en Koda": adds a catalog product (or free text) to the shopping list. Works offline; the
/// `SyncEngine` sends it later (`source = 'siri'`).
struct AddToShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.add-shopping.title"
    static let description = IntentDescription("intent.add-shopping.description")
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "intent.product.type")
    var product: ProductEntity?

    @Parameter(title: "intent.add-shopping.item")
    var item: String?

    @Dependency var services: IntentServices

    init() {}

    init(product: ProductEntity) {
        self.product = product
    }

    static var parameterSummary: some ParameterSummary {
        Summary("intent.add-shopping.summary \(\.$product)") {
            \.$item
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let added: String
        if let product {
            _ = try await services.addShoppingEntry.execute(
                NewShoppingEntry(item: .product(product.id), source: .siri)
            )
            added = product.name
        } else {
            let text = try await resolvedText()
            if let match = await services.products().first(where: {
                $0.name.compare(text, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) {
                _ = try await services.addShoppingEntry.execute(
                    NewShoppingEntry(item: .product(match.id), source: .siri)
                )
                added = match.name
            } else {
                _ = try await services.addShoppingEntry.execute(NewShoppingEntry(item: .text(text), source: .siri))
                added = text
            }
        }
        return .result(dialog: "intent.add-shopping.done \(added)")
    }

    private func resolvedText() async throws -> String {
        let current = item?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !current.isEmpty { return current }
        let asked = try await $item.requestValue("intent.add-shopping.ask")
        let text = asked.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw $item.needsValueError("intent.add-shopping.ask") }
        return text
    }
}

/// "Añade la receta lentejas a la compra en Koda": one grouped entry with the recipe's products.
struct AddRecipeToShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.add-recipe.title"
    static let description = IntentDescription("intent.add-recipe.description")
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "intent.recipe.type")
    var recipe: RecipeEntity

    @Dependency var services: IntentServices

    init() {}

    init(recipe: RecipeEntity) {
        self.recipe = recipe
    }

    static var parameterSummary: some ParameterSummary {
        Summary("intent.add-recipe.summary \(\.$recipe)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try await services.addRecipeToShoppingList.execute(
            recipeID: recipe.id,
            servings: nil,
            source: .siri,
            mealPlanEntryID: nil
        )
        return .result(dialog: "intent.add-recipe.done \(recipe.name)")
    }
}
