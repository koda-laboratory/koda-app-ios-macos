import Foundation

/// The plan-meal sheet: when, which slot, a recipe or a free text, an optional own time and servings.
struct PlanMealFormState: FormState {
    enum Kind: String, Sendable, CaseIterable {
        case recipe
        case text
    }

    var day: LocalDay
    var slot: MealSlot
    var kind: Kind = .recipe
    var recipeID: UUID?
    var freeText = ""
    var usesCustomTime = false
    var time = SlotTimes.default.dinner
    var servings: Double = 2

    var trimmedText: String { freeText.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isValid: Bool {
        switch kind {
        case .recipe: recipeID != nil
        case .text: !trimmedText.isEmpty
        }
    }

    var scheduledTime: LocalTime? { usesCustomTime ? time : nil }
}
