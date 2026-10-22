---
name: data-layer
description: Build or review Koda repositories, repository protocols, DataSources, DTOs, GRDB records, remote Supabase requests, and Keychain/local persistence. Use when implementing a backend contract, mapping transport or database data to domain models, coordinating local and remote sources, or changing storage; not for UI or business rules.
---

# Data Layer

Implement provider access and mapping behind repository boundaries. Koda is local-first: for product data the repository's primary source is the local GRDB database (see the `local-first` rule and the `local-first-sync` skill); remote calls are for auth, the sync engine, and a few server-side operations.

## Scope

- Data sources: `Koda/Features/<Feature>/DataSources/`
- Repository protocols: `Koda/Features/<Feature>/Repositories/Protocols/`
- Repository implementations: `Koda/Features/<Feature>/Repositories/`
- DTOs: `Koda/Features/<Feature>/Models/DTOs/`
- Cross-feature infrastructure: `Koda/Core/Api/` (HTTP + `Providers/Supabase/`), `Koda/Core/DataSources/` (Keychain, volatile cache), `Koda/Core/Repositories/` (session), planned `Koda/Core/Database/` (GRDB `AppDatabase`, migrations, records, outbox)

## References

- Read [repository-datasource-patterns.md](references/repository-datasource-patterns.md) when implementing local/remote providers, GRDB writes with outbox, cache orchestration, or repository mapping.
- Read [dto-request-patterns.md](references/dto-request-patterns.md) when defining DTOs, `SupabaseRequest` endpoints, dates, or headers.
- Read the `supabase-api` skill before adding an endpoint and `local-first-sync` before touching GRDB tables, the outbox, or sync.

## Boundary

```text
UseCase -> Repository -> DataSource -> GRDB / HTTP (Supabase) / Keychain / cache
                      -> DTO or Record mapping -> Domain model
```

- A repository is the only data-layer dependency exposed to a use case.
- Repositories choose and coordinate data sources, define local/remote ownership, and map DTOs and records into domain models.
- Data sources interact directly with one provider: the database, `HTTPService`, Keychain, key-value storage, filesystem, or a platform API.
- Data sources do not contain business rules. Repositories do not contain UI or presentation state.
- Never expose DTOs or GRDB records above the repository boundary.

## Backend contracts

- The contract is owned by `../koda-backend` (Supabase Auth under `/auth/v1`, Edge Function `api` under `/functions/v1/api`). Treat its paths, methods, headers, bodies, response shapes, and error behavior as authoritative.
- Do not invent or modify backend behavior from the app. If the contract is incomplete and the missing choice materially changes behavior, report the gap.
- Model endpoint declarations as typed `SupabaseRequest` values and let the shared header provider (`apikey`, bearer token) and decoding infrastructure do their job.

## Data sources and repositories

- Define protocols for replaceable provider boundaries and `final` implementations (or actors when they own mutable state) with constructor injection.
- Keep remote endpoint declarations in `Koda/Core/Api/Providers/Supabase/` (`AuthAPI.swift`, planned `KodaAPI.swift`) or next to their owning remote data source.
- Product writes: one GRDB transaction writes the row and the outbox mutation together. Reads: `ValueObservation` exposed as `AsyncStream`.
- Keep Keychain, user-defaults, file, and database access behind data sources. When a shared Core data source already covers the provider, inject it into the repository directly; never create a feature data source that wraps it.
- Data sources never depend on other data sources; only repositories combine them.
- A repository combining local and remote sources must make ordering, fallback, and invalidation explicit.

## DTOs, records, and conversion

- Separate request, response, body, and parameter DTOs when doing so makes the transport contract clearer. GRDB records (`FetchableRecord`, `PersistableRecord`) mirror table rows and stay inside the data layer.
- Apply `Encodable`, `Decodable`, `Sendable`, and `Equatable` according to actual use. Supabase JSON is `snake_case`; declare `CodingKeys` (or a configured key strategy) explicitly.
- Use `DTOConvertible` / `DomainConvertible`-style initializers for conversions; perform mapping at the repository boundary, not in ViewModels.
- Decode dates through the shared decoder configuration; keep plain calendar days (`date` columns) as day values in the household time zone.
- Preserve backend optionality unless the repository can establish a valid domain default.

## Workflow

1. Inspect the contract, existing `SupabaseRequest` patterns, the database schema/migrations, and the target feature assembly.
2. Model DTOs/records exactly, then implement the provider-specific data source.
3. Implement repository orchestration and conversion.
4. Register data source and repository in the assembly.
5. Test mapping, error propagation, transaction/outbox behavior (in-memory GRDB), and remote calls with a fake `HTTPTransport`.
6. Validate that no DTO, record, HTTP type, or persistence detail escapes to domain or presentation code.
