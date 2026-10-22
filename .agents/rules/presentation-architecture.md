---
description: Keep Koda ViewModels and multi-input forms on the shared lightweight MVI contract
alwaysApply: true
---

# Presentation architecture

Koda uses a lightweight MVI-style presentation layer. It keeps unidirectional user actions
without recreating TCA's store, reducer, dependency, or effect systems.

## ViewModels

Every feature ViewModel must:

- be a `@MainActor`, `@Observable`, `final class` in `Koda/Features/<Feature>/ViewModels/<Name>ViewModel.swift`, registered in the feature assembly;
- model every deterministic presentation state machine with a feature-specific `Sendable`,
  `Equatable` enum and expose it through a read-only state property;
- conform to `MVIViewModel`;
- define a feature-specific `Sendable` intent enum;
- expose `send(_:) async` as the only public entry point for user and lifecycle actions;
- model initial view work as an `.appeared` intent and call it from SwiftUI's `.task` modifier;
- keep use-case calls and effect-specific state transitions in private methods;
- expose observable state for rendering and bindings, but never expose use cases, repositories,
  data sources, or services to a View.

The state enum must model mutually exclusive lifecycle, request, validation-feedback, success,
failure, and completion states as explicit cases. Use associated values for data that only exists
in a particular state. A transition must assign the new state instead of coordinating several
stored flags. Prefer `state` for the primary state machine; when genuinely independent workflows
can run concurrently, use focused enum substates such as `searchState` and `submissionState`
instead of inventing a combinatorial monolithic enum.

Stored deterministic flags are prohibited. Do not store or independently mutate properties such
as `isLoading`, `hasLoaded`, `showsError`, `showsValidationErrors`, `didSucceed`, or
`shouldDismiss` when their value is determined by the current state. A read-only computed property
derived exclusively from `state` is allowed when it makes View code clearer, but it must never add
a second source of truth.

Lifecycle entry must not use generic `hasStarted`, `hasLoaded`, `didLoad`, or equivalent Boolean
flags. Keep `.task { await viewModel.send(.appeared) }` as the shared view entry point and choose the
guard from the work's actual lifetime:

- For a one-time data load, model an explicit initial state such as `.idle` or `.preparing`, change
  it before the first suspension point, and guard `.appeared` with that state.
- For work that should repeat on every appearance, run it directly from `.appeared` without a
  one-time guard so SwiftUI owns cancellation and restart through `.task`.
- For observations that intentionally live for the ViewModel lifetime, store a focused
  `@ObservationIgnored Task?`, use `nil` as the subscription guard, assign it synchronously before
  any suspension, and cancel it in `deinit`. Do not add a second Boolean for the same lifetime.
- When loaded data belongs to a session, remember the session identity that produced it instead of
  using a Boolean such as `hasLoadedForSession`.

Do not introduce `onLoad`, `viewDidLoad`, or generic `taskOnce` view modifiers for product loading.
They tie business behavior to SwiftUI view identity and can bypass `.task` cancellation. A
once-per-view modifier is only appropriate for a strictly visual effect with no product state.

Transient operation failures that do not change what the screen can render should normally use a
toast (planned shared toast presenter in `Common/Presentation/Toast/`) and return the operation state to its idle case. Keep a failure case only when the screen has
dedicated, persistent failure UI or when retry behavior depends on retaining that state.

Independent values that can vary orthogonally remain focused observable properties instead of
being forced into the state enum. This includes editable form values, loaded domain data,
user-controlled toggles, selected filters, and item-driven sheet or navigation destinations. A
`Bool` is valid when it represents a genuine independent two-state value, not one case of a larger
presentation state machine.

Do not introduce a base ViewModel class or add generic reducers and effect wrappers merely to
resemble TCA. The feature state should encode valid presentation transitions without becoming a
monolithic container for every binding and domain value.

Views may own local UI-only state such as focus or the presentation of a child sheet. Product
behavior and business state belong to the ViewModel and must change through an intent.

## Forms

A screen with two or more related editable inputs must define a feature-specific
`<Feature>FormState` value under that feature's `Models/Forms/` folder. It must conform to the
shared `FormState` protocol and:

- contain only editable values and configuration that directly changes the form;
- expose `isValid` and any cross-field validation presentation as computed properties;
- keep normalization and cross-field rules out of the View;
- remain `Sendable` and `Equatable`;
- be owned by the ViewModel as `var form`, with that ViewModel conforming to `FormViewModel`.

Bind controls through the typed state, for example `$viewModel.form.email`. Keep loading phases,
navigation, alerts, and other presentation state outside the form. A screen with only one input
does not need a form wrapper unless the field has genuinely complex internal state.

Views must not invoke validators directly. They render form-derived properties and send intents;
the ViewModel consumes the validated or normalized form values when invoking a use case.

## Async actions

Use `.task { await viewModel.send(.appeared) }` for view-lifetime work so SwiftUI owns cancellation.
Synchronous button closures may bridge to an async intent with `Task { await viewModel.send(...) }`.
Do not hide arbitrary fire-and-forget work inside a generic base type, and do not use
`Task.detached` for ViewModel effects.

## Local-first observation

Koda screens render local data (see [`local-first`](local-first.md)). A ViewModel that shows
product data subscribes to an observation use case (GRDB `ValueObservation` exposed as an
`AsyncStream`) from `.appeared`, keeps the stream task in a focused `@ObservationIgnored Task?`,
and never models a "waiting for the network" state for data that already lives in the database.
Mutations write locally through a use case and return immediately; sync progress is shown by the
shared offline/pending indicator, not by per-screen loading states.
