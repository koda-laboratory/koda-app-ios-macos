import Foundation

/// Nutrient tags of a recipe (`recipes.nutrients`).
enum Nutrient: String, CaseIterable, Sendable, Codable {
    case fats
    case fiber
    case vegetables
    case protein
    case carbs
}

struct Recipe: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let mealTypes: [MealSlot]
    let nutrients: [Nutrient]
    let timeMinutes: Int?
    /// Servings the ingredient quantities are written for.
    let servings: Double
    let steps: [String]
    let notes: String?
    let imagePath: String?
    let emoji: String?
    let isFavorite: Bool
}

struct RecipeIngredient: Sendable, Equatable, Identifiable {
    let id: UUID
    let recipeID: UUID
    let productID: UUID
    let productName: String
    let productEmoji: String?
    let quantity: Double?
    let unit: String?
    let position: Int
}

/// "Pollo al horno" includes "Patatas al airfryer" (`servingsFactor` servings of the child per serving).
struct RecipeComponent: Sendable, Equatable, Identifiable {
    let id: UUID
    let parentRecipeID: UUID
    let childRecipeID: UUID
    let childRecipeName: String
    let childRecipeEmoji: String?
    let servingsFactor: Double
    let position: Int
}

struct RecipeDetail: Sendable, Equatable {
    let recipe: Recipe
    let ingredients: [RecipeIngredient]
    let components: [RecipeComponent]
}

/// Values to create (`id == nil`) or update a recipe's own fields.
struct RecipeInput: Sendable, Equatable {
    var id: UUID?
    var name: String
    var mealTypes: [MealSlot] = []
    var nutrients: [Nutrient] = []
    var timeMinutes: Int?
    var servings: Double = 2
    var steps: [String] = []
    var notes: String?
    var emoji: String?
    var isFavorite = false
}

struct RecipeIngredientInput: Sendable, Equatable {
    var recipeID: UUID
    var productID: UUID
    var quantity: Double?
    var unit: String?
}
