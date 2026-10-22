---
description: Keep Koda SwiftUI screens, components, sheets, navigation, and previews structured consistently on iPhone and Mac
alwaysApply: true
---

# SwiftUI structure

Koda is a native SwiftUI app for iPhone and Mac built from one multiplatform target (not Catalyst, no iPad layout). Every screen and component is shared by both platforms; platform differences follow [`multiplatform`](multiplatform.md).

## Screens and components

- Destinations live in `Koda/Features/<Feature>/Screens/<Name>View.swift`. A screen owns (or receives) its ViewModel, starts work with `.task { await viewModel.send(.appeared) }`, and renders state; it never calls use cases, repositories, or services.
- Extract to `Koda/Features/<Feature>/Components/<Name>.swift` when a section is interactive, reused within the feature, owns local UI state, or represents a named UI concept.
- Extract to `Koda/Common/Presentation/<Type>/` when two or more features use it. Group by component type (`Button`, `Card`, `Chip`, `Input`, `Header`, `EmptyState`, `Banner`, `Loading`, …); never add a flat catch-all folder.
- Components receive data and closures, not ViewModels. A reusable card reports an action; it never navigates.

## Extracting subviews

A computed property or method returning `some View` is an acceptable local shorthand when the fragment is small, single-purpose, stateless, and represented by one view expression. It does not need `@ViewBuilder` unless it must directly support multiple sibling views or control-flow branches.

Use a dedicated `struct: View` when a section is interactive, owns or observes state, accepts changing input, is reused, contains meaningful conditional layout, or is large enough to represent a named UI concept. A dedicated view gives SwiftUI its own identity and dependency boundary; a computed subview is reevaluated with its containing view.

Do not store preconstructed SwiftUI view values in ordinary `let` or `var` properties. Pass the data needed to construct the view, use a generic `@ViewBuilder` closure for configurable container content, or extract a dedicated view type.

## Design system

Use the Koda design system (skill [`koda-design-system`](../skills/koda-design-system/SKILL.md)) for every element with product chrome:

- Tokens live in `Koda/Common/Theme/`: `KodaColor` (brand constants and adaptive semantic colors), `KodaSpacing`, `KodaRadius`, `KodaTypography`, `KodaGradient`, and the signature `KodaArcs` motif. Never hard-code hex colors, font sizes, paddings, or corner radii in features; avoid magic layout constants unless they describe an intentional design token or asset size.
- Components (planned, created as features need them) live in `Koda/Common/Presentation/<Type>/`: `KodaCard`, `MealCard`, `RecipeTile`, `ChipView`, `SectionHeader`, `EmptyStateView`, `PrimaryButton` (`.glassProminent`), `QuickAddField`, `CheckRow`, `WeekStrip`, `StatPill`, `OfflineBanner`, `DraftBanner`. Reuse an existing component before writing a new one, and add new reusable ones there.
- Do not style a native `Button` with a `ViewModifier` that wraps it to create a primary/secondary button: the modifier wraps the `Button` rather than its label, so the visible background can extend beyond the hit region. Use `PrimaryButton` or a `ButtonStyle`. A native `Button` remains valid for bespoke interactive surfaces or native system presentation.
- Icons: SF Symbols through `Image(systemName:)` / `Label(_:systemImage:)` are allowed in Koda (see `ios-icons`). Keep symbol names in one place per feature when they repeat.
- Liquid Glass only on navigation and controls (tab bar/sidebar, toolbars, the "+" button, sheets); never on content cards.

## Navigation

Build value-based push navigation on the central `AppRouter` in `Koda/Core/Navigation/`. `AppRouter` owns the selected `AppTab` (`today`, `planning`, `shopping`, `recipes`) and an independent `[AppRoute]` path per tab. The root uses one `TabView` with `.tabViewStyle(.sidebarAdaptable)`: a Liquid Glass tab bar on iPhone and a sidebar on the Mac. Profile is reached from the avatar on iPhone and lives in the `Settings` scene (⌘,) on the Mac.

Keep `AppRoute` limited to hashable, sendable destination data. Use `NavigationLink(value:)` for direct user navigation and `AppRouter.navigate(to:in:)` for programmatic pushes. Feature screens must not create their own root `NavigationStack`, duplicate destination modifiers, or maintain a second path array.

Keep item-driven sheets in their owning ViewModel. Do not move feature sheet state into `AppRouter`; coordinate a sheet-to-push transition by dismissing first and navigating from `onDismiss`.

## Sheets

- Prefer item-driven `.sheet(item:)` with detents sized to the content; keep `.large` for long, scrollable, or keyboard-heavy flows. Do not use `.medium` as an approximation of content height.
- On the Mac, sheets render as windows attached to the main window: give them a sensible `presentationSizing`/frame and a visible cancel/confirm toolbar, because there is no swipe-to-dismiss.
- Sheets with text inputs apply `.dismissKeyboard()` (see `keyboard-dismissal`).

## Previews

Every SwiftUI screen and reusable component must have `#Preview`s, plus variants for meaningful states (default, loading, empty, error, disabled, selected, long content), light and dark, an iPhone variant, and a Mac variant (for example `traits: .fixedLayout(width: 1000, height: 700)` or a preview run on the My Mac destination).

- Always declare previews in the same file as the view, at the bottom, under a `// MARK: - Previews` section wrapped in `#if DEBUG`. Never create separate `+Preview.swift` files.
- Preview-only helpers (private wrapper views, preview data) live in that same section. Prefer `@Previewable @State` for bindings.
- Shared fixtures and preview dependencies are provided by deterministic factories in `Koda/Common/Preview/<Feature>/<Feature>PreviewFactory.swift` (`Common/Preview/Presentation/` for design-system components). Factories contain no `#Preview`, use local data only (in-memory database, no network, no production credentials), and screens that need a container use `DependencyContainer(previewAssemblies:)`.
- Finish every preview with `.kodaPreview()` (defined in `Koda/Common/Theme/`): it fills the canvas with the Koda background and installs the same environment as the app root.
- The app skips bootstrap, session restoration, and networking while Xcode hosts previews (`ProcessInfo.isRunningForPreviews`); keep new launch-time work behind that check.

When reviewing a screen:

1. Keep only trivial static fragments as computed `some View` properties; extract meaningful or state-driven sections into dedicated view structs.
2. Confirm extracted components live in `Components/` or `Common/Presentation/<Type>/`.
3. Confirm only design-system tokens and components are used for product chrome.
4. Confirm value-based navigation uses `AppRouter` and the tab-owned central stack.
5. Confirm the layout reads well on a compact iPhone, a large iPhone, and a resizable Mac window (sidebar + detail, hover states, keyboard shortcuts where useful).
6. Confirm the view file ends with a `// MARK: - Previews` section covering the default state, meaningful variants, and iPhone + Mac variants, with fixtures coming from `Common/Preview/`.
