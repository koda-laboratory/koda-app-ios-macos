import SwiftUI

extension MealSlot {
    /// "Desayuno", "Comida", "Merienda", "Cena".
    var titleKey: LocalizedStringKey {
        switch self {
        case .breakfast: "slot.breakfast"
        case .lunch: "slot.lunch"
        case .snack: "slot.snack"
        case .dinner: "slot.dinner"
        }
    }

    var titleResource: LocalizedStringResource {
        switch self {
        case .breakfast: "slot.breakfast"
        case .lunch: "slot.lunch"
        case .snack: "slot.snack"
        case .dinner: "slot.dinner"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: "sun.horizon"
        case .lunch: "fork.knife"
        case .snack: "cup.and.saucer"
        case .dinner: "moon.stars"
        }
    }

    /// "Se marcará como cenada a las 21:30."
    func willMarkKey(time: String) -> LocalizedStringKey {
        switch self {
        case .breakfast: "today.meal.will-mark.breakfast \(time)"
        case .lunch: "today.meal.will-mark.lunch \(time)"
        case .snack: "today.meal.will-mark.snack \(time)"
        case .dinner: "today.meal.will-mark.dinner \(time)"
        }
    }
}

extension Nutrient {
    var titleKey: LocalizedStringKey {
        switch self {
        case .fats: "nutrient.fats"
        case .fiber: "nutrient.fiber"
        case .vegetables: "nutrient.vegetables"
        case .protein: "nutrient.protein"
        case .carbs: "nutrient.carbs"
        }
    }

    var titleResource: LocalizedStringResource {
        switch self {
        case .fats: "nutrient.fats"
        case .fiber: "nutrient.fiber"
        case .vegetables: "nutrient.vegetables"
        case .protein: "nutrient.protein"
        case .carbs: "nutrient.carbs"
        }
    }
}

extension ProductCategory {
    var titleKey: LocalizedStringKey {
        switch self {
        case .food: "category.food"
        case .basics: "category.basics"
        case .cleaning: "category.cleaning"
        case .kitchen: "category.kitchen"
        case .bathroom: "category.bathroom"
        case .toiletries: "category.toiletries"
        }
    }

    var titleResource: LocalizedStringResource {
        switch self {
        case .food: "category.food"
        case .basics: "category.basics"
        case .cleaning: "category.cleaning"
        case .kitchen: "category.kitchen"
        case .bathroom: "category.bathroom"
        case .toiletries: "category.toiletries"
        }
    }
}
