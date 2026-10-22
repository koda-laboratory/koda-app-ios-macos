# View Composition Patterns

## Screen as composition root

The screen owns its ViewModel, reads environment presentation dependencies, renders state, and converts interactions into intents:

```swift
PrimaryButton("login.submit", isLoading: viewModel.state.isLoading) {
    Task { await viewModel.send(.submit) }
}
```

The button stays enabled for validation; invalid submission moves the ViewModel to `.invalidForm` and the fields render inline errors. Request phases drive button loading rather than a screen-wide spinner.

The screen observes completion and performs the native dismissal; the ViewModel owns the product outcome:

```swift
.onChange(of: viewModel.state) {
    if viewModel.state == .completed { dismiss() }
}
```

## Named components over massive bodies

Extract small named `View` types (for example `MealSlotRow`, `ShoppingSectionHeader`) when a fragment has a name, conditions, or meaningful layout. Keep a computed `some View` property only for a small stateless expression.

Reusable concepts move to `Koda/Common/Presentation/<Type>/` (planned: `Card/KodaCard.swift`, `Card/MealCard.swift`, `Chip/ChipView.swift`, `Header/SectionHeader.swift`, `EmptyState/EmptyStateView.swift`, `Button/PrimaryButton.swift`, `Input/QuickAddField.swift`, `List/CheckRow.swift`, `Calendar/WeekStrip.swift`, `Banner/OfflineBanner.swift`, `Banner/DraftBanner.swift`). Feature-specific sections remain under `Features/<Feature>/Components/`.

## Local view state versus product state

Valid local view state includes focus, hover, a strictly component-local nested presentation, or coordination needed by a native callback (for example a pending route to push after a sheet dismisses).

Move state to the ViewModel when it represents:

- a business or request phase;
- which product destination is presented;
- loaded data, validation, or a mutation outcome;
- behavior that must survive view recomposition or be testable through intents.

## One screen, two platforms

The same screen serves iPhone and Mac. Adapt through SwiftUI, not duplication:

- `TabView` with `.sidebarAdaptable` gives a tab bar on iPhone and a sidebar on the Mac.
- Use `NavigationSplitView` or adaptive grids (`GridItem(.adaptive(minimum:))`) so wider Mac windows show more columns.
- Add `.keyboardShortcut`, `.onHover`/`.hoverEffect`, context menus, and toolbar items; they are harmless on iPhone.
- When a real platform difference is unavoidable, call a small helper from `Koda/Core/Platform/` instead of writing `#if os(...)` in the feature.

Prefer an explicit presentation input (for example `enum RecipeListPresentation { case tab, picker }`) over inferring context from device size.

## Design system and hit regions

- Use Koda components and tokens for product chrome; native `Button`, `NavigationLink`, `Menu`, toolbar, sheet, and alert APIs when native behavior is the requirement.
- Put the full visual surface inside the interactive label. Do not attach a background modifier outside a small text-only button label.
- Use `KodaSpacing`, `KodaRadius`, `KodaTypography`, and `KodaColor`. A fixed image dimension is valid when it is an intentional asset size; arbitrary layout constants are not.
- Liquid Glass only on navigation and controls, never on content cards.

## Preview architecture

- Factories: `Koda/Common/Preview/<Feature>/<Feature>PreviewFactory.swift` construct deterministic dependencies (in-memory data, no network) and return the real screen/component.
- Previews: `#Preview` blocks at the bottom of the same view file under `// MARK: - Previews`, wrapped in `#if DEBUG`, finished with `.kodaPreview()`.

```swift
#if DEBUG
    #Preview("Shopping — iPhone") {
        ShoppingPreviewFactory.makeShoppingListView(configuration: .populated)
            .kodaPreview()
    }

    #Preview("Shopping — Mac", traits: .fixedLayout(width: 1000, height: 700)) {
        ShoppingPreviewFactory.makeShoppingListView(configuration: .populated)
            .kodaPreview()
    }
#endif
```

Add variants for meaningful loading, empty, offline/pending, error, long-content, selected, disabled, light, and dark states.

## Anti-patterns

- A reusable DS component stored in a feature screen file.
- A screen calling a use case directly.
- Hardcoded localized copy, hex colors, or font sizes.
- `#if os(...)` or `import UIKit`/`import AppKit` inside a feature.
- `GeometryReader` used only to discover the whole window width when adaptive layout can accept the parent's proposal.
- A `#Preview` outside `#if DEBUG`, or preview data built inline instead of in a factory.
