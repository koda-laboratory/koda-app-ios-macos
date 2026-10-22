import Foundation
import UserNotifications

/// Visible notifications of Koda v1: the defrost reminder (`koda.kind = "defrost"`, category `DEFROST`).
enum KodaNotification {
    static let defrostCategory = "DEFROST"
    static let viewRecipeAction = "VIEW_RECIPE"

    /// Registers the `DEFROST` category with its "Ver receta" action. Call at every launch.
    static func registerCategories() {
        let viewRecipe = UNNotificationAction(
            identifier: viewRecipeAction,
            title: String(localized: "notification.defrost.view-recipe"),
            options: [.foreground]
        )
        let defrost = UNNotificationCategory(
            identifier: defrostCategory,
            actions: [viewRecipe],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([defrost])
    }

    /// The destination of a tapped notification (the default tap and "Ver receta" both open the recipe).
    static func route(for userInfo: [AnyHashable: Any]) -> AppRoute? {
        guard let koda = userInfo["koda"] as? [String: Any], koda["kind"] as? String == "defrost",
            let recipeID = (koda["recipe_id"] as? String).flatMap(UUID.init(uuidString:))
        else {
            return nil
        }
        return .recipe(id: recipeID)
    }
}
