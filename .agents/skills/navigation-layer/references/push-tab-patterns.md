# Push and Tab Patterns

Reference: `Koda/Core/Navigation/AppRouter.swift`. Feature destinations named below are planned (PLAN section 5).

## Router

```swift
enum AppTab: String, Hashable, Sendable, CaseIterable {
    case today, planning, shopping, recipes
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab = AppTab.today
    private var paths: [AppTab: [AppRoute]] = [:]

    func path(for tab: AppTab) -> [AppRoute] { paths[tab] ?? [] }
    func setPath(_ path: [AppRoute], for tab: AppTab) { paths[tab] = path }
    func navigate(to route: AppRoute, in tab: AppTab? = nil) { /* append to tab path */ }
}
```

- One router per app lifetime, injected with `.environment(router)`.
- Each tab owns its path; switching sections keeps history.

## Root TabView (iPhone tab bar, Mac sidebar)

```swift
TabView(selection: $router.selectedTab) {
    Tab("tab.today", systemImage: "sun.max", value: AppTab.today) {
        AppTabNavigationStack(tab: .today) { TodayView() }
    }
    // planning, shopping, recipes …
}
.tabViewStyle(.sidebarAdaptable)
```

Keep the `TabView` in one root view; never nest another `TabView` or root `NavigationStack` inside a feature.

## Routes

```swift
enum AppRoute: Hashable, Sendable {
    case recipe(id: UUID)
    case product(id: UUID)
    case mealPlanDraft(id: UUID)
}
```

- Only stable identifiers or tiny immutable snapshots.
- `AppRouteDestination` switches over `AppRoute` once and builds each destination through its assembly factory.

## Direct and programmatic pushes

```swift
NavigationLink(value: AppRoute.recipe(id: recipe.id)) {
    RecipeTile(recipe: recipe)
}
.buttonStyle(.plain)
```

```swift
@Environment(AppRouter.self) private var router
router.selectedTab = .recipes
router.navigate(to: .recipe(id: id), in: .recipes)
```

## Mac commands

```swift
.commands {
    CommandGroup(after: .newItem) {
        Button("command.new-recipe") { router.selectedTab = .recipes; /* send intent */ }
            .keyboardShortcut("n")
        Button("command.shopping-list") { router.selectedTab = .shopping }
            .keyboardShortcut("l", modifiers: [.command, .shift])
    }
}
```

Commands select a section or forward an intent; they do not instantiate screens. On iPhone the same shortcuts work with a hardware keyboard.

## Previews

Wrap pushed content in `AppTabNavigationStack(tab:)` with an injected `AppRouter` when push behavior is part of the preview.

## Anti-patterns

- `NavigationPath`, `AnyHashable`, or string routes.
- A feature screen owning a `NavigationStack` or a second path array.
- Separate iPhone and Mac screen hierarchies for the same section.
- `#if os(macOS)` inside a feature to change navigation; use SwiftUI adaptivity or a helper in `Core/Platform/`.
