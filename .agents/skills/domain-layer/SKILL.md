---
name: domain-layer
description: Build or review Koda UseCases and Services in feature or Core domain code. Use for business operations (recipes, nested recipe expansion, meal planning, consumptions, shopping list), reusable domain logic, repository/service orchestration, or domain-ready outputs; not for SwiftUI, DTO, HTTP, GRDB, or Keychain implementation.
---

# Domain Layer

Express Koda business behavior through small, testable use cases and focused domain services.

## Scope

- Feature use cases: `Koda/Features/<Feature>/UseCases/`
- Cross-feature use cases: `Koda/Core/UseCases/` (session: `Core/UseCases/Session/`, for example `RefreshSessionUseCase`)
- Feature services when behavior belongs to one feature: `Koda/Features/<Feature>/Services/`
- Cross-feature services: `Koda/Core/Services/` (for example `SessionService`)
- Domain models shared upward by repositories and use cases (`Koda/Core/Models/`, `Features/<Feature>/Models/`)

## References

- Read [usecase-patterns.md](references/usecase-patterns.md) when creating or changing a use case, choosing its input/output, or coordinating repositories.
- Read [service-patterns.md](references/service-patterns.md) when deciding whether shared logic or a long-lived event stream belongs in a service.

## Dependency rules

```text
ViewModel -> UseCase -> Repository / Service
Service -> Repository or owned infrastructure abstraction
```

- A use case may call repositories and services only.
- A use case must never call another use case. If two use cases share business logic, extract that logic into a service.
- A service must never call another service or a use case.
- Do not import SwiftUI/UIKit/AppKit, expose presentation state, decode DTOs, touch GRDB records, or perform raw HTTP, Keychain, `UserDefaults`, database, or filesystem operations here.
- Inject every dependency through the initializer. Do not reach into the dependency container from domain code.

## Use case shape

- Define a descriptive protocol and a `final` implementation, following the established `Sendable` conventions.
- Expose one public operation named `execute`. Split unrelated operations into separate use cases.
- Keep the operation focused on one user or business outcome, even when it coordinates multiple repository calls.
- Return a domain model or domain value; observation use cases return `AsyncStream<DomainModel>` built from the repository's GRDB observation.
- Use a named input model when several arguments form one business request; do not create wide parameter lists.
- Preserve cancellation and structured concurrency.
- Write use cases are local-first: they complete when the local write (and outbox entry) is committed, never after a network round trip.

## Services

Create a service only when at least one of these is true:

- multiple use cases share a non-trivial business rule (for example expanding nested recipes into aggregated products);
- the behavior represents a long-lived domain capability such as session observation;
- a provider-specific infrastructure concern needs a stable domain-facing abstraction.

Keep services cohesive. A service is not a miscellaneous helper collection and must not become a path around repository boundaries.

## Errors and models

- Use `KodaError` at established boundaries; do not leak provider-specific errors upward.
- Keep domain models independent of response payload layout, GRDB schema, and UI formatting.
- Dates (meal plan days in the household time zone `Europe/Madrid`), identifiers (client UUIDs), and optionality must already have domain meaning when returned from this layer.

## Workflow

1. Read the repository/service protocols and neighboring use cases before designing the operation.
2. Confirm no existing use case already owns the same outcome.
3. Decide whether shared logic belongs in a service rather than chaining use cases.
4. Implement the smallest protocol and constructor-injected implementation.
5. Register it in the appropriate assembly and add focused Swift Testing tests with fakes at repository/service boundaries.
6. Validate every caller receives domain-ready output and no DTO, record, or provider type crosses upward.
