import AppIntents

/// Siri phrases and the Shortcuts / Spotlight tiles. Phrases are a public contract: add new ones, never rename
/// or remove shipped ones. Spanish phrases live in `AppShortcuts.xcstrings`; every phrase names the app, and
/// carries at most one entity parameter (Siri free-form language is not available in the EU).
struct KodaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodayMealsIntent(),
            phrases: [
                "What's on the menu today in \(.applicationName)",
                "What do we eat today in \(.applicationName)",
                "What's for dinner today in \(.applicationName)",
            ],
            shortTitle: "intent.today.short",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: AddToShoppingListIntent(),
            phrases: [
                "Add \(\.$product) to the shopping list in \(.applicationName)",
                "Add \(\.$product) in \(.applicationName)",
                "Add to the shopping list in \(.applicationName)",
            ],
            shortTitle: "intent.add-shopping.short",
            systemImageName: "cart.badge.plus"
        )
        AppShortcut(
            intent: AddRecipeToShoppingListIntent(),
            phrases: [
                "Add the recipe \(\.$recipe) to the shopping list in \(.applicationName)",
                "Add a recipe to the shopping list in \(.applicationName)",
            ],
            shortTitle: "intent.add-recipe.short",
            systemImageName: "book.closed"
        )
        AppShortcut(
            intent: ShowShoppingListIntent(),
            phrases: [
                "Show the shopping list in \(.applicationName)",
                "What's left to buy in \(.applicationName)",
            ],
            shortTitle: "intent.show-shopping.short",
            systemImageName: "bag"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
