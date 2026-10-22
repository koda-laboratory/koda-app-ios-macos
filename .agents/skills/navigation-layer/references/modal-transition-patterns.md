# Modal and Transition Patterns

## Feature-owned sheets

```swift
enum PlanningSheet: Sendable, Equatable, Identifiable {
    case pickRecipe(date: Date, slot: MealSlot)
    case reviewDraft(id: UUID)

    var id: String {
        switch self {
        case let .pickRecipe(date, slot): "pick-\(date.timeIntervalSince1970)-\(slot.rawValue)"
        case let .reviewDraft(id): "draft-\(id)"
        }
    }
}
```

```swift
.sheet(item: $viewModel.presentedSheet) { sheet in
    PlanningSheetContent(sheet: sheet)
}
```

- The ViewModel sets and clears `presentedSheet` through intents (`.pickRecipe(...)`, `.dismissSheet`).
- `PlanningSheetContent` resolves cases and applies presentation configuration (detents on iPhone, sizing on Mac).
- Sheets with text inputs apply `.dismissKeyboard()`.

## Sheet to push

1. The sheet reports the chosen destination (for example a recipe id).
2. The screen stores `pendingRoute` (local UI coordination state) and sends `.dismissSheet`.
3. In `onDismiss`, the screen calls `router.navigate(to: pendingRoute)` and clears it.

Never push while the sheet is still on screen.

## Mac specifics

- Sheets are attached windows: give them a frame or `presentationSizing(.form)`-style sizing and explicit toolbar buttons (`.cancellationAction`, `.confirmationAction`).
- Profile/settings live in the `Settings` scene instead of a sheet.
- Consider an additional `WindowGroup(for: UUID.self)` only when a document-like detail (for example a recipe) genuinely benefits from its own window; route it through the same destination view.

## Zoom transition (card → detail)

```swift
// Source
RecipeTile(recipe: recipe)
    .matchedTransitionSource(id: transitionID, in: namespace)

// Destination
RecipeDetailView(id: recipe.id)
    .navigationTransition(.zoom(sourceID: transitionID, in: namespace))
```

- The namespace is owned by `AppTabNavigationStack` and read from the environment.
- Transition IDs include the collection context when the same recipe can appear twice (for example Today and Planning).
- Keep these modifiers in `Common/Presentation/Navigation/`; if an API is unavailable on one platform, wrap it in a helper backed by `Core/Platform/` rather than writing `#if os` in features.

## Deep links, intents, and notifications

- Root `.onOpenURL` → deep-link resolution (planned `Core/DeepLink/`) → typed result → `AppRouter` push/tab or feature modal.
- `OpenRecipeIntent` and Spotlight results resolve to `AppRoute.recipe(id:)`.
- Future visible notifications: `UNUserNotificationCenterDelegate` → `NotificationRouter` → the same typed resolution (see `push-notifications`).
- Coordinate pending sheets/alerts before presenting another destination; never trigger competing presentations at once.

## Anti-patterns

- Boolean flags per sheet (`showsPicker`, `showsDraft`).
- Sheet state stored in `AppRouter`.
- Presenting a sheet from a reusable component that does not own the product destination.
- Different modal flows for iPhone and Mac for the same feature.
