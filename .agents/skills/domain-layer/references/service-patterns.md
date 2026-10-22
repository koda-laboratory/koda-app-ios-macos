# Service Patterns

Create a service for a reusable domain capability, not as a mandatory layer between use cases and repositories.

## Session service: state plus event publication

Reference: `Koda/Core/Services/SessionService.swift`

`SessionServiceImpl` is an actor because it owns mutable subscriber state and serializes session storage operations. It depends on `SessionRepository`, maps storage failures to `KodaError`, and publishes changes after successful save/delete:

```swift
actor SessionServiceImpl: SessionService {
    private let repository: any SessionRepository
    private var continuations: [UUID: AsyncStream<UserSession?>.Continuation] = [:]

    func save(_ session: UserSession) async throws(KodaError) {
        try await repository.save(session)   // mapped to KodaError
        publish(session)
    }

    func delete() async throws(KodaError) {
        try await repository.delete()
        publish(nil)
    }
}
```

It is shared by login, refresh, logout, restoration, request headers, and observing screens, so duplicating it in use cases would create inconsistent session side effects.

## Observation use case adapts a service

An observation use case yields the current session first, then forwards service events, and cancels the forwarding task on termination. The ViewModel does not implement that stream composition itself.

## Pure domain rule service

A planned `RecipeExpansionService` flattens a recipe tree (recipe + sub-recipes with `servings_factor`) into aggregated products. It has no repository and no state: it is a pure, heavily tested rule used by the shopping, planning, intent, and widget flows.

## When not to create a service

Do not create `RecipeService` merely to forward `recipe(id:)` to `RecipeRepository`. A focused use case can call the repository directly.

Do not turn a service into a helper namespace for formatting, DTO conversion, or view state. Put:

- reusable domain capability/state in a service;
- one business operation in a use case;
- provider/database access in repositories/data sources;
- pure generic formatting in an appropriately scoped utility;
- presentation formatting in the ViewModel or presentation model.

The `SyncEngine` is infrastructure (Core/Sync), not a domain service: use cases never call it; triggers live in the app layer and Core.

## Dependency restrictions

- Service dependencies are constructor-injected.
- A service may call repositories or an infrastructure abstraction it owns.
- A service never calls another service or a use case.
- Prefer an actor when the service owns mutable shared state or stream continuations. Do not add actor isolation to a stateless rule without a concurrency reason.

## Anti-patterns

```swift
// Wrong: service chain obscures ownership and can form cycles.
final class ProfileServiceImpl {
    let sessionService: SessionService
    let householdService: HouseholdService
}

// Wrong: global mutable singleton bypasses testable injection.
SessionServiceImpl.shared.save(session)

// Correct: inject the protocol into the use case initializer.
init(sessionService: any SessionService) { ... }
```
