import Foundation

/// Moves a planned meal to another day or slot, swaps its recipe or changes its time ("Cambiar").
protocol UpdatePlannedMealUseCase: Sendable {
    @discardableResult
    func execute(entryID: UUID, _ update: MealPlanEntryUpdate) async throws(KodaError) -> MealPlanEntry
}

final class UpdatePlannedMealUseCaseImpl: UpdatePlannedMealUseCase, Sendable {
    private let repository: any PlanningRepository

    init(repository: any PlanningRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(entryID: UUID, _ update: MealPlanEntryUpdate) async throws(KodaError) -> MealPlanEntry {
        var normalized = update
        normalized.freeText = update.freeText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.freeText?.isEmpty == true { normalized.freeText = nil }
        guard normalized.recipeID != nil || normalized.freeText != nil else {
            throw KodaError(type: .badRequest, reason: "A planned meal needs a recipe or a text.")
        }
        if let servings = normalized.servings, servings <= 0 {
            throw KodaError(type: .badRequest, reason: "Servings must be positive.")
        }
        return try await repository.updateEntry(id: entryID, normalized)
    }
}
