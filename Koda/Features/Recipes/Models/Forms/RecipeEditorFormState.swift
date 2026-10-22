import Foundation

/// The recipe editor: own fields, ingredients (product + quantity + unit), sub-recipes and reorderable steps.
struct RecipeEditorFormState: FormState {
    struct IngredientRow: Sendable, Equatable, Identifiable {
        let id: UUID
        var ingredientID: UUID?
        var productID: UUID
        var productName: String
        var quantityText: String
        var unit: String

        var quantity: Double? { RecipeEditorFormState.number(quantityText) }
        var isQuantityValid: Bool { quantityText.trimmingCharacters(in: .whitespaces).isEmpty || (quantity ?? 0) > 0 }
    }

    struct ComponentRow: Sendable, Equatable, Identifiable {
        let id: UUID
        var componentID: UUID?
        var childRecipeID: UUID
        var name: String
        var servingsFactor: Double
    }

    struct StepRow: Sendable, Equatable, Identifiable {
        let id: UUID
        var text: String
    }

    var name = ""
    var emoji = ""
    var mealTypes: Set<MealSlot> = []
    var nutrients: Set<Nutrient> = []
    var timeText = ""
    var servings: Double = 2
    var isFavorite = false
    var notes: String?
    var ingredients: [IngredientRow] = []
    var components: [ComponentRow] = []
    var steps: [StepRow] = []

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var timeMinutes: Int? { Int(timeText.trimmingCharacters(in: .whitespaces)) }
    var isTimeValid: Bool { timeText.trimmingCharacters(in: .whitespaces).isEmpty || (timeMinutes ?? -1) >= 0 }

    var isValid: Bool {
        !trimmedName.isEmpty && servings > 0 && isTimeValid && ingredients.allSatisfy(\.isQuantityValid)
    }

    /// Parses "1,5" and "1.5".
    static func number(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    func input(id: UUID?) -> RecipeInput {
        RecipeInput(
            id: id,
            name: trimmedName,
            mealTypes: MealSlot.allCases.filter(mealTypes.contains),
            nutrients: Nutrient.allCases.filter(nutrients.contains),
            timeMinutes: timeMinutes,
            servings: servings,
            steps: steps.map(\.text),
            notes: notes,
            emoji: emoji.isEmpty ? nil : emoji,
            isFavorite: isFavorite
        )
    }

    var ingredientDrafts: [RecipeIngredientDraft] {
        ingredients.map { row in
            RecipeIngredientDraft(
                id: row.ingredientID,
                productID: row.productID,
                quantity: row.quantity,
                unit: row.unit.trimmingCharacters(in: .whitespaces).isEmpty ? nil : row.unit
            )
        }
    }

    var componentDrafts: [RecipeComponentDraft] {
        components.map {
            RecipeComponentDraft(id: $0.componentID, childRecipeID: $0.childRecipeID, servingsFactor: $0.servingsFactor)
        }
    }
}
