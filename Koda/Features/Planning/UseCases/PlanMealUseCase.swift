import Foundation

/// Plans a recipe (or a free-text meal) on a day and slot.
protocol PlanMealUseCase: Sendable {
    @discardableResult
    func execute(_ input: NewMealPlanEntry) async throws(KodaError) -> MealPlanEntry
}

final class PlanMealUseCaseImpl: PlanMealUseCase, Sendable {
    private let repository: any PlanningRepository

    init(repository: any PlanningRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(_ input: NewMealPlanEntry) async throws(KodaError) -> MealPlanEntry {
        var normalized = input
        normalized.freeText = input.freeText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.freeText?.isEmpty == true { normalized.freeText = nil }
        guard normalized.recipeID != nil || normalized.freeText != nil else {
            throw KodaError(type: .badRequest, reason: "A planned meal needs a recipe or a text.")
        }
        if let servings = normalized.servings, servings <= 0 {
            throw KodaError(type: .badRequest, reason: "Servings must be positive.")
        }
        return try await repository.planMeal(normalized)
    }
}
