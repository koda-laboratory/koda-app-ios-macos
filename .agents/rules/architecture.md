---
description: Keep Koda layered as View → ViewModel → UseCase → Repository → DataSource with Swinject-owned dependencies and a local-first data path
alwaysApply: true
---

# Architecture

```text
View / Component -> ViewModel -> UseCase -> Repository (protocol) -> DataSource -> GRDB / HTTP provider / Keychain / UserDefaults
                                    |               |
                                    v               v
                                 Service       DTO / Record -> domain mapping
```

Koda is local-first (see [`local-first`](local-first.md)): repositories read and write the local GRDB database and enqueue outbox mutations; the `SyncEngine` is the only component that moves data between the database and the backend. The same code runs on iPhone and Mac (see [`multiplatform`](multiplatform.md)).

## Layers and placement

- **Presentation** (`Koda/Features/<Feature>/{Screens,Components,ViewModels,Models/Forms,Utils}`, `Koda/Common/Presentation/<Type>/`): follows [`presentation-architecture`](presentation-architecture.md) and [`swiftui-structure`](swiftui-structure.md).
- **Domain** (`Features/<Feature>/UseCases`, `Features/<Feature>/Services`, domain models in `Features/<Feature>/Models`, `Koda/Core/UseCases/`, `Koda/Core/Services/`, `Koda/Core/Models/`): plain Swift. No SwiftUI, UIKit, AppKit, DTOs, GRDB records, SQL, or endpoint paths.
- **Data** (`Features/<Feature>/{Repositories,DataSources,Models/DTOs}`, `Koda/Core/{Api,DataSources,Repositories}`, planned `Koda/Core/Database/`): DTOs and GRDB records never leave the repository; repositories return domain models.
- **Core** (`Koda/Core/`): cross-feature infrastructure — HTTP client and the Supabase provider (`Core/Api/`), session, errors (`Core/Error/KodaErrorCenter.swift`), logging, Keychain (`Core/Security/`), navigation, platform abstractions (`Core/Platform/`), and the planned database, sync, notifications, and deep links.
- **Composition** (`Koda/App/`, `Koda/Assembly/`): `KodaApp`, the per-platform `AppDelegate`s (`App/iOS/`, `App/macOS/`), and the Swinject assemblies.

## Dependency rules

- A ViewModel depends on use cases only. Never inject a repository, data source, database, API provider, or SDK into a ViewModel. A service is allowed only when a focused use case cannot express a long-lived observation.
- A use case depends on repository protocols and services, never on data sources.
- Repositories depend on data sources. Data sources alone perform GRDB, HTTP, Keychain, UserDefaults, file, or SDK access.
- A data source never depends on another data source. Each one talks to exactly one provider; combining sources is the repository's job.
- Repositories inject the shared Core data sources (`VolatileDataSource`, `KeychainPersistentDataSource`, the planned database access) directly. Do not wrap one in a feature-specific data source that only forwards to it.
- Use cases and services never call other use cases or other services.
- Product repositories write locally and enqueue the outbox in the same transaction; they never call the sync endpoints themselves.

## Protocols and registration

- Repositories: protocol in `Features/<Feature>/Repositories/Protocols/<Name>Repository.swift`, implementation `<Name>RepositoryImpl.swift`. Cross-feature repositories live in `Koda/Core/Repositories/`.
- Use cases and services are protocols with an `Impl`, consumed as `any <Name>UseCase`.
- Register every implementation in `Koda/Assembly/Assembly+<Feature>.swift` (Swinject, `DependencyContainer`). ViewModels are built by assembly factories (for example `Assembly.make<Feature>ViewModel(...)`); `@Inject` resolves shared dependencies where a factory is not needed.
- Do not add a service locator call inside domain or data types; pass dependencies through initializers.

## Concurrency

- Swift 6 language mode (`SWIFT_VERSION = 6`). ViewModels are `@MainActor`; stateful services, data sources, and the `SyncEngine` are actors or `Sendable` types.
- Use structured concurrency; SwiftUI `.task` owns view-lifetime cancellation. Do not use `Task.detached` for product work.
- Rethrow or propagate `CancellationError`; never convert it into a user-facing error.

## API contract

The backend lives in `../koda-backend` (Supabase) and owns the contract:

- **Auth** goes directly to Supabase Auth (GoTrue) under `/auth/v1` (`token?grant_type=password`, `token?grant_type=refresh_token`, `logout`) through `Koda/Core/Api/Providers/Supabase/AuthAPI.swift`. Every request sends the `apikey` header with the publishable key; authenticated requests add `Authorization: Bearer <access JWT>`.
- **Product data** goes through the Edge Function `api` (`/functions/v1/api/...`: `/me`, `/sync/push`, `/sync/pull`, `/devices`, `/drafts`, `/shopping/from-plan`). Do not invent routes or payloads; when the contract is missing, report the gap.
- Requests are typed values built on `SupabaseRequest`; failures surface as `KodaError` (`KodaErrorMapper`) and are published through `KodaErrorCenter`.
- A 401 triggers single-flight session recovery: `HTTPSessionRecovery` (actor) runs one `RefreshSessionUseCase` for all concurrent callers, because Supabase rotates refresh tokens and reusing one revokes the session. Auth endpoints use `allowsSessionRecovery: false`. A refresh rejected with `invalid_grant` forces login without deleting the local database or the outbox.
- Never log tokens, passwords, raw auth responses, the publishable key, or household data.
