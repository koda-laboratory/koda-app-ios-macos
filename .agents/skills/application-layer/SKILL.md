---
name: application-layer
description: Build or review Koda presentation code in Screens, Components, ViewModels, and presentation Forms for iPhone and Mac. Use for SwiftUI screens and components, MVI state and intents, form behavior, design-system composition, previews, or presentation-only logic; not for domain or data work alone.
---

# Application Layer

Implement the presentation edge of a Koda feature. The same screens run on iPhone and Mac (see the `multiplatform` rule).

## Scope

- Feature screens: `Koda/Features/<Feature>/Screens/`
- Feature components: `Koda/Features/<Feature>/Components/` (views only)
- Feature utilities: `Koda/Features/<Feature>/Utils/` for pure, stateless helpers such as formatters and copy builders; never inside `Components/`
- Feature ViewModels: `Koda/Features/<Feature>/ViewModels/`
- Presentation forms: `Koda/Features/<Feature>/Models/Forms/`
- Reusable UI: `Koda/Common/Presentation/<ComponentType>/`
- Design tokens: `Koda/Common/Theme/` (see `koda-design-system`)
- Previews: `#Preview` at the bottom of the same view file; fixture factories in `Koda/Common/Preview/<Feature>/`

Before changing this layer, read the repository rules `presentation-architecture`, `swiftui-structure`, `multiplatform`, `local-first`, and, when the screen contains editable text, `keyboard-dismissal`.

For SwiftUI work, load `swiftui-expert-skill` (and `swiftui-specialist` for Apple best practices). Add `koda-design-system`, `navigation-layer`, `app-resizability`, `ios-localization`, `ios-icons`, `swift-concurrency`, or `ios-ui-automation` only when the work needs them.

## References

- Read [viewmodel-patterns.md](references/viewmodel-patterns.md) when creating or changing MVI state, intents, forms, observation of local data, async operations, or modal destinations.
- Read [view-composition-patterns.md](references/view-composition-patterns.md) when composing screens/components, choosing local view state, using the design system, adapting to iPhone and Mac, or adding previews.

## Boundary

```text
Screen / Component -> ViewModel -> UseCase -> Repository / Service
```

- Views render observable state and send intents. They do not call use cases, services, repositories, or data sources.
- ViewModels own presentation state, validation feedback, transient effects, and presentation-ready transformations.
- A ViewModel depends on use cases. Direct service access is exceptional and requires a concrete lifetime or observation reason that a focused use case cannot express cleanly.
- Never inject a repository, data source, or database into a ViewModel.
- Do not expose DTOs or GRDB records to presentation code. Consume domain models returned by use cases.

## MVI contract

- Use a `@MainActor @Observable final class` conforming to `MVIViewModel`.
- Define feature-specific `Sendable` intent and state enums.
- Route user and lifecycle actions through `send(_:) async`; use `.appeared` from `.task` for view-lifetime work.
- Represent deterministic, mutually exclusive states with enum cases and associated values.
- Do not store deterministic flags such as `isLoading`, `hasLoaded`, `didSucceed`, `showsError`, or `shouldDismiss`. A read-only value derived from the state is allowed.
- Keep independent user-controlled values, selections, sheet destinations, and form fields as focused observable properties when they are genuinely orthogonal.
- Local data is observed, not fetched: subscribe to an observation use case from `.appeared`; never model "waiting for the network" for data that lives in GRDB.
- Prefer a toast for transient failures that do not replace the screen's renderable content.

Do not introduce generic reducers, effect wrappers, or base ViewModels merely to imitate a larger state-management framework.

## Composition and forms

- Keep a screen readable at a glance. Extract interactive, stateful, conditional, reusable, or conceptually named sections into dedicated `View` types.
- Put reusable design-system elements under `Common/Presentation/<Type>/`; do not collect unrelated components in a flat folder.
- Use Koda design-system components (`PrimaryButton`, `KodaCard`, `ChipView`, …) and tokens (`KodaColor`, `KodaSpacing`, `KodaRadius`, `KodaTypography`).
- For two or more related editable fields, create `<Feature>FormState` under `Models/Forms`, conform to `FormState`, and keep normalization and cross-field validation there.
- Avoid magic layout constants unless they describe an intentional design token or a fixed asset dimension. Prefer adaptive layout proposals and platform-native containers so the same view works in a compact iPhone and a resizable Mac window.
- Every new or materially changed screen and reusable component needs `#Preview` coverage at the bottom of the same view file (`// MARK: - Previews`, inside `#if DEBUG`) with iPhone and Mac variants, backed by a deterministic preview factory in `Koda/Common/Preview/`.

## Workflow

1. Inspect neighboring presentation code, current state machines, routes, design-system components, and previews.
2. Define observable behavior and valid state transitions before editing the view hierarchy.
3. Implement the ViewModel boundary, then compose the screen and components from that state.
4. Register new ViewModels and dependencies in the feature assembly when necessary.
5. Add accessibility identifiers to meaningful interactions and previews for important states.
6. Validate according to `development` on iPhone and Mac and the relevant UI/testing skills.
