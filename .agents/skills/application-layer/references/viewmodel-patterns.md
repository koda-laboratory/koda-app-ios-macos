# ViewModel Patterns

Koda's features are still being built; the type names below (`ShoppingListViewModel`, `LoginViewModel`, …) illustrate the planned features from `../PLAN.md`. Read the current files before editing because state machines evolve with the product.

## One deterministic state machine

A login screen has mutually exclusive phases. Model them as one enum and derive loading instead of storing a flag:

```swift
enum LoginState: Sendable, Equatable {
    case idle
    case invalidForm
    case submitting
    case completed

    var isLoading: Bool { self == .submitting }
}
```

Expose one intent entry point and keep use-case calls in private methods:

```swift
func send(_ intent: LoginIntent) async {
    switch intent {
    case .submit: await submit()
    case .clearError: state = .idle
    }
}
```

Why:

- `state` is the only source of truth for request/validation/completion phases.
- `form` is independent editable state, not packed into the phase enum.
- Field errors are computed from `state` and `form`.
- The ViewModel calls `LoginUseCase`; it knows no repository, DTO, or token.
- A failed login resets to `.idle` and raises a toast because the screen remains usable.

Do not replace this with `isLoading`, `showValidation`, `didComplete`, and `shouldDismiss` Booleans that must be synchronized across methods.

## Forms: values and validation stay together

```swift
struct LoginFormState: FormState {
    var email = ""
    var password = ""

    var normalizedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    var isValid: Bool { normalizedEmail.contains("@") && !password.isEmpty }
}
```

The View binds to `$viewModel.form.email`; it does not invoke validators. Keep loading, navigation, alerts, and request phases outside the form.

## Observing local data (local-first)

Screens render GRDB data through an observation use case. The stream lives for the ViewModel lifetime:

```swift
@ObservationIgnored private var observation: Task<Void, Never>?
private(set) var entries: [ShoppingEntry] = []

private func startObserving() {
    guard observation == nil else { return }
    observation = Task { [observeShoppingList] in
        for await entries in observeShoppingList.execute() {
            self.entries = entries
        }
    }
}

deinit { observation?.cancel() }
```

- `nil` is the subscription guard; do not add a Boolean for the same lifetime.
- Mutations (`.toggle(entry)`, `.add(text)`) call a use case that writes GRDB + outbox and return immediately; the observation delivers the new rows.
- There is no "loading from server" state for this data. Sync status is shown by the shared offline/pending indicator.

## Independent workflows use focused substates

A recipe editor can search products while a save is in flight:

```swift
enum RecipeEditorSearchState: Sendable, Equatable { case idle, searching }
enum RecipeEditorSubmissionState: Sendable, Equatable {
    case idle
    case submitting
    case invalidName(String)
    case completed(Recipe)
}
```

This is preferable to a combinatorial enum or unrelated flags such as `isSearching`, `isSubmitting`, `hasNameError`, and `didComplete`. Debounce ownership is explicit through a cancellable `Task`.

## Item-driven destinations are state, not flags

```swift
enum PlanningSheet: Sendable, Equatable, Identifiable {
    case pickRecipe(date: Date, slot: MealSlot)
    case reviewDraft(MealPlanDraft)
    var id: String { /* stable identity */ }
}

var presentedSheet: PlanningSheet?
```

Do not create `showsRecipePicker`, `showsDraft`, and separate selected-item storage. Those flags allow impossible simultaneous presentations.

## Collection state and pending identity

Keep selected filters, loaded items, and identity sets such as `pendingEntryIDs` separate from lifecycle enums because they vary independently. Identity sets keep unrelated rows interactive and let the UI render the affected item precisely.

## Anti-patterns

```swift
// Wrong: repositories bypass the domain boundary.
final class FeatureViewModel {
    let repository: FeatureRepository
}

// Wrong: public methods create multiple uncontrolled entry points.
func load() async { ... }
func retry() async { ... }

// Correct: intents describe user/lifecycle actions.
func send(_ intent: FeatureIntent) async { ... }
```

Also avoid:

- a `.failed` state that replaces usable content for a transient mutation error;
- awaiting a network request before updating the UI for a local mutation;
- an unstructured `Task` without cancellation for debounced or replaceable work;
- presentation formatting or localized error selection inside repositories/use cases.
