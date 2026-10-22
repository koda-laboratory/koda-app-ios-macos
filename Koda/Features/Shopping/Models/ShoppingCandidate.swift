import Foundation

/// A planned recipe meal the "Generar compra" sheet can add to the list.
struct ShoppingCandidate: Sendable, Equatable, Identifiable {
    let entry: MealPlanEntry
    /// Products the recipe (with its sub-recipes) adds.
    let productCount: Int
    /// Its shopping was already generated (`shopping_entries.meal_plan_entry_id`).
    let isAlreadyOnList: Bool

    var id: UUID { entry.id }
}
