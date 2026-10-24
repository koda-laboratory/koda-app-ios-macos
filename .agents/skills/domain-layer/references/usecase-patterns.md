# Use Case Patterns

Feature use cases below are illustrative names from the Comidita module. Session use cases in `Koda/Core/UseCases/Session/` are real.

## Pure repository delegation

```swift
protocol GetRecipeUseCase: Sendable {
    func execute(id: UUID) async throws(KodaError) -> Recipe
}

final class GetRecipeUseCaseImpl: GetRecipeUseCase, Sendable {
    private let recipeRepository: any RecipeRepository

    init(recipeRepository: any RecipeRepository) {
        self.recipeRepository = recipeRepository
    }

    func execute(id: UUID) async throws(KodaError) -> Recipe {
        try await recipeRepository.recipe(id: id)
    }
}
```

Use this shape when the repository already exposes the exact domain operation. The use case still provides a stable application boundary.

## Observation use case

```swift
protocol ObserveShoppingListUseCase: Sendable {
    func execute() -> AsyncStream<[ShoppingEntry]>
}
```

The repository turns a GRDB `ValueObservation` into an `AsyncStream`; the use case may filter or shape it (for example hide checked entries older than a day) but never polls the network.

## Focused orchestration and domain shaping

"Add a recipe to the shopping list" expands nested recipes (`recipe_components`, with cycle protection and `servings_factor`), aggregates products by `product_id + unit`, and writes one `shopping_entry` of kind `recipe` with its `shopping_entry_items`:

```swift
let tree = try await recipeRepository.recipeTree(id: input.recipeID)
let items = recipeExpansionService.flatten(tree, servings: input.servings)
return try await shoppingRepository.addRecipeEntry(recipe: tree.root, items: items, source: input.source)
```

The aggregation rule is domain logic shared with intents and the planning flow, so it lives in a service; the repository persists locally and enqueues the outbox in one transaction.

## Repository plus shared service

`RefreshSessionUseCase` (Core) coordinates the auth repository and `SessionService`: it reads the stored session, exchanges the refresh token, and saves the rotated session. The caller receives a domain `UserSession`, never a GoTrue DTO or a Keychain record. It is invoked only through the single-flight `HTTPSessionRecovery`.

## Several rules, still one business outcome

A startup use case may decide one outcome (`.locked`, `.signedOut`, `.ready(UserSession)`) by reading the session and the biometric-lock preference. It calls repositories and services directly; it does not call other use cases. Private helpers keep the decision tree readable.

## Inputs and outputs

- Prefer one domain input such as `NewMealPlanEntry` when fields describe one operation.
- Return a domain model/value (`Recipe`, `[MealPlanEntry]`, `ShoppingEntry`, `UserSession`).
- Command use cases return the updated entity or an explicit outcome so callers can reconcile state; avoid an uninformative `Void` for new code.
- Do not return response DTOs, GRDB records, `HTTPURLResponse`, Keychain records, or UI state.

## Error policy

Use typed `KodaError` for recoverable failures when the caller must distinguish them. Do not catch an error merely to return a fabricated empty model.

## Anti-patterns

```swift
// Wrong: use-case chaining.
final class AddPlanToShoppingUseCaseImpl {
    let addRecipeToShoppingUseCase: AddRecipeToShoppingUseCase
}

// Correct: share the rule through a service and depend on repositories.
final class AddPlanToShoppingUseCaseImpl {
    let planningRepository: PlanningRepository
    let shoppingRepository: ShoppingRepository
    let recipeExpansionService: RecipeExpansionService
}
```

Also avoid:

- more than one public operation on a use case;
- a use case formatting localized text or constructing SwiftUI state;
- direct `HTTPService`, GRDB, Keychain, `UserDefaults`, or filesystem access;
- waiting for sync before returning from a local write;
- resolving dependencies from `Assembly` inside `execute`.
