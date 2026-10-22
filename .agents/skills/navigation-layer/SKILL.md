---
name: navigation-layer
description: Build or refactor Koda navigation on iPhone and Mac using typed routes, per-tab stacks, the sidebar-adaptable TabView, feature-owned modal destinations, the macOS Settings scene and menu commands, deep links, and native transitions. Use for push, tab, sheet, window, or programmatic navigation.
---

# Koda Navigation Layer

Treat navigation as an application layer with explicit ownership and typed destinations. Do not introduce feature coordinators or parallel routers.

## Required context

Before changing navigation, read:

- [`../../rules/development.md`](../../rules/development.md)
- [`../../rules/swiftui-structure.md`](../../rules/swiftui-structure.md)
- [`../../rules/multiplatform.md`](../../rules/multiplatform.md)
- [`../../rules/presentation-architecture.md`](../../rules/presentation-architecture.md)
- [`../application-layer/SKILL.md`](../application-layer/SKILL.md)
- [`../swiftui-expert-skill/references/sheet-navigation-patterns.md`](../swiftui-expert-skill/references/sheet-navigation-patterns.md) when a flow crosses a sheet boundary
- [`../app-resizability/SKILL.md`](../app-resizability/SKILL.md) for Mac windows and sidebar/detail layouts

The app-wide push implementation lives in `Koda/Core/Navigation/` (`AppRouter`, `AppTab`, `AppRoute`). Reusable transition helpers belong in `Koda/Common/Presentation/Navigation/`.

## References

- Read [push-tab-patterns.md](references/push-tab-patterns.md) when adding routes, tab stacks, reusable navigation entry points, Mac commands, or programmatic navigation.
- Read [modal-transition-patterns.md](references/modal-transition-patterns.md) when working with sheets, full-screen covers, sheet-to-push coordination, deep links, notification routing, or zoom transitions.

## Ownership model

```text
KodaApp (WindowGroup + Settings on macOS + .commands)
└── root view with AppRouter in the environment
    └── TabView(selection: $router.selectedTab).tabViewStyle(.sidebarAdaptable)
        ├── one AppTabNavigationStack per AppTab (today, planning, shopping, recipes)
        │   └── AppRouteDestination resolves typed pushes
        └── feature screen
            ├── ViewModel owns feature modal destinations
            └── screen maps them to sheet/full-screen content
```

### Root, tabs, and platforms

- The root creates one `AppRouter` for the app lifetime and injects it through the environment.
- `AppTab` is the canonical section identity: `today`, `planning`, `shopping`, `recipes`. `AppRouter.selectedTab` owns the current section.
- `AppRouter` keeps an independent `[AppRoute]` for every tab so switching sections preserves each history.
- `.sidebarAdaptable` renders a Liquid Glass tab bar on iPhone and a sidebar on the Mac; the stacks and routes are identical.
- Profile: on iPhone a sheet opened from the avatar; on the Mac the `Settings` scene (⌘,). Both host the same Profile screen.
- Mac menu commands (⌘N new recipe, ⌘⇧L shopping list) live in `.commands` at the app level and call `AppRouter` or send a feature intent through a focused value — they never duplicate screens.
- Changing tabs and pushing are separate operations. Set `selectedTab` explicitly when the UX changes section; `navigate(to:in:)` only appends to the chosen tab's path.

### Typed push navigation

- `AppRoute` is the complete set of app-level push destinations. Cases contain only stable, immutable, `Hashable` and `Sendable` input (typically a UUID).
- `AppRouteDestination` is the single resolver from `AppRoute` to destination screen.
- `AppTabNavigationStack` binds the tab's typed path and registers `navigationDestination(for: AppRoute.self)` once.
- Use `NavigationLink(value:)` for a direct user-driven push; read `AppRouter` from the environment and call `navigate(to:in:)` for programmatic pushes.
- Only `AppRouter` mutates path arrays. Feature screens must not keep their own push path.

Do not use `NavigationPath`, `AnyHashable`, string route names, destination-based `NavigationLink`, duplicated destination modifiers, or feature-owned root stacks.

## Reusable navigation entry points

- A component representing a concrete destination (for example a planned `RecipeTile`) builds a typed `AppRoute` and wraps its interactive surface in `NavigationLink(value:)`, with `.buttonStyle(.plain)` when design-system chrome must remain unchanged.
- A generic component whose destination depends on its caller accepts an `AppRoute?`.
- If the required destination has no valid identifier, render the content without a link rather than inventing a route.
- Use a callback only when the component must request navigation across a presentation boundary. Pass a typed `AppRoute`, not a destination view or string.

Do not pass ViewModels, repositories, bindings, closures, or fully loaded screen state in `AppRoute`.

## Native zoom transitions

PLAN section 10 asks for a zoom transition from a card to its detail. Keep the source/destination modifiers in `Common/Presentation/Navigation/`, own the `@Namespace` in `AppTabNavigationStack`, and include collection context in the transition ID when the same entity can appear several times on screen. Platforms without the native zoom keep the same typed route with a no-op modifier provided through `Core/Platform/` if needed.

## Modal and full-screen navigation

Sheets are feature-owned destinations, not `AppRoute` cases:

- Model mutually exclusive destinations with a feature-specific `Sendable`, `Equatable`, `Identifiable` enum (for example `PlanningSheet`).
- The ViewModel owns `presentedSheet` and changes it through intents.
- The screen attaches one item-driven `.sheet(item:)` for that destination family and resolves cases in a dedicated `*SheetContent` view.
- On the Mac, give sheets explicit sizing and visible confirm/cancel actions.

Do not push while a sheet is still presented: store the pending typed route, dismiss through the ViewModel, then call `AppRouter` from `onDismiss`.

Alerts, confirmation dialogs, toasts, and loading overlays are presentation state, not navigation destinations.

## Deep links and notifications

- Capture incoming URLs (and, in the future, notification responses through a `NotificationRouter`) at the root and resolve them into typed intent in `Core/DeepLink/` (planned).
- Map the result to an `AppRoute` push, a tab selection, or a feature-owned modal destination following the same ownership rules.
- App Intents that open the app (`OpenRecipeIntent`) use the same resolution path.

## Adding or changing navigation

1. Classify the destination as tab selection, app-level push, feature modal, Mac window/command, or isolated navigation island.
2. Reuse an existing route or destination enum case when it represents the same identity and input.
3. For a push, add the case to `AppRoute`, map it once in `AppRouteDestination`, then use a value-based link or `AppRouter`.
4. For a modal, add the feature destination case, its stable ID, ViewModel intent/state transition, and content-resolver mapping.
5. Update preview hosts to inject `AppRouter` and wrap the content in `AppTabNavigationStack` when push behavior is part of the preview.
6. Remove obsolete local stacks, path state, or string routing superseded by the typed flow.

## Validation

- Verify direct links, programmatic pushes, back navigation, tab/sidebar history preservation, modal dismissal, sheet-to-push ordering, and Mac menu commands.
- Verify the iPhone tab bar and the Mac sidebar, including window resizing.
- Run the Xcode MCP builds required by `development` (iPhone + Mac) and formatting, lint, and focused tests in proportion to the change.
