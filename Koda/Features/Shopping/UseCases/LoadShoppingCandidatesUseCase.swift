import Foundation

/// The planned recipe meals between two days for "Generar compra", marking the ones already on the list.
/// Free-text and skipped meals are left out.
protocol LoadShoppingCandidatesUseCase: Sendable {
    func execute(from: LocalDay, through: LocalDay) async throws(KodaError) -> [ShoppingCandidate]
}

final class LoadShoppingCandidatesUseCaseImpl: LoadShoppingCandidatesUseCase, Sendable {
    private let planningRepository: any PlanningRepository
    private let shoppingRepository: any ShoppingRepository
    private let recipeRepository: any RecipeRepository
    private let expansionService: any RecipeExpansionService

    init(
        planningRepository: any PlanningRepository,
        shoppingRepository: any ShoppingRepository,
        recipeRepository: any RecipeRepository,
        expansionService: any RecipeExpansionService
    ) {
        self.planningRepository = planningRepository
        self.shoppingRepository = shoppingRepository
        self.recipeRepository = recipeRepository
        self.expansionService = expansionService
    }

    func execute(from: LocalDay, through: LocalDay) async throws(KodaError) -> [ShoppingCandidate] {
        guard from <= through else { return [] }
        let entries = try await planningRepository.entries(from: from, through: through)
            .filter { $0.isRecipe && !$0.isSkipped }
        guard !entries.isEmpty else { return [] }
        let onList = try await shoppingRepository.mealPlanEntryIDsOnList()
        let graph = try await recipeRepository.recipeGraph()
        return entries.compactMap { entry in
            guard let recipeID = entry.recipeID else { return nil }
            let count =
                (try? expansionService.expand(recipeID: recipeID, servings: entry.servings, in: graph))?
                .items.count ?? 0
            return ShoppingCandidate(entry: entry, productCount: count, isAlreadyOnList: onList.contains(entry.id))
        }
    }
}
