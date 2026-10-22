import Foundation

/// Opens the plan-meal sheet: a new meal (optionally with a recipe chosen) or an existing one to change.
enum PlanMealRequest: Sendable, Equatable, Identifiable {
    case new(day: LocalDay, slot: MealSlot, recipeID: UUID?)
    case edit(MealPlanEntry)

    var id: String {
        switch self {
        case .new(let day, let slot, let recipeID): "new-\(day)-\(slot.rawValue)-\(recipeID?.uuidString ?? "")"
        case .edit(let entry): "edit-\(entry.id)"
        }
    }
}
