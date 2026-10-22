---
name: supabase-api
description: Add or change a Koda HTTP endpoint against Supabase — typed SupabaseRequest values, Supabase Auth (GoTrue) under /auth/v1 in AuthAPI.swift, Edge Function `api` routes under /functions/v1/api in KodaAPI.swift, headers (apikey + bearer), configuration from Info.plist, KodaError mapping, session recovery, DataSource/Repository wiring, and tests with a fake HTTPTransport. Use whenever the app talks to the backend. Not for GRDB/outbox logic (local-first-sync).
---

# Supabase API

The app does **not** use supabase-swift. It reuses the HTTP stack ported from Gotty in `Koda/Core/Api/`:

```text
DataSource -> HTTPService (recovery + error publication) -> HTTPRequestExecutor (one attempt, logging) -> HTTPTransport (URLSession)
```

The contract is owned by `../koda-backend`. **Never invent routes, fields, or status semantics**; read the backend (functions, migrations, tests) and report gaps.

## Configuration

- `SupabaseEnvironment` reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from `Info.plist`, which gets them from `Configuration/Koda.xcconfig` (URL) and the ignored `Configuration/Koda.private.xcconfig` (key; see `Koda.private.xcconfig.example`).
- Only the publishable key (`sb_publishable_…`) ships in the app. Secret keys (`sb_secret_…`) and the legacy `anon`/`service_role` keys never appear in this repository.
- There is one environment (project `koda`): tests must never hit it.

## Files

| File | Content |
| --- | --- |
| `Core/Api/Providers/Supabase/SupabaseRequest.swift` | generic typed request: path, method, query items, body, decoding, error handling policy, `allowsSessionRecovery` |
| `Core/Api/Providers/Supabase/SupabaseHeaders.swift` | header names (`apikey`, `Authorization`, `Content-Type`, …) |
| `Core/Api/Providers/Supabase/SupabaseEnvironment.swift` | base URL and publishable key |
| `Core/Api/Providers/Supabase/AuthAPI.swift` | GoTrue requests: password grant, refresh-token grant, logout |
| `Core/Api/Providers/Supabase/KodaAPI.swift` (planned) | Edge Function `api` requests |

Read the current `SupabaseRequest.swift` before adding an endpoint; follow its initializer instead of the illustrative snippets below.

## Auth endpoints (GoTrue)

| Request | Route | Notes |
| --- | --- | --- |
| Login | `POST /auth/v1/token?grant_type=password` `{ email, password }` | returns access token (1 h), rotating refresh token, `expires_in`/`expires_at`, user |
| Refresh | `POST /auth/v1/token?grant_type=refresh_token` `{ refresh_token }` | refresh tokens rotate; reuse outside the ~10 s window revokes the session |
| Logout | `POST /auth/v1/logout` | bearer = current access token |

- Every request sends `apikey: <publishable key>`. Auth requests use `allowsSessionRecovery: false` and do not trigger recovery on 4xx.
- Refresh is executed only by `RefreshSessionUseCase` through the single-flight `HTTPSessionRecovery` actor; never refresh from features, widgets, or intents.
- `invalid_grant`-style refresh failures force login (`KodaErrorCenter` publishes `forceLogin`) **without** clearing the local database or outbox. Network failures during refresh do not log the user out.
- Registration is disabled server-side; there is no sign-up request.

## Edge Function `api` (planned `KodaAPI.swift`)

Routes under `/functions/v1/api`: `GET /me`, `POST /sync/push`, `GET /sync/pull`, `PUT /devices`, `DELETE /devices/:id`, `POST /drafts/:id/accept|discard`, `POST /recipes/:id/expand`, `POST /shopping/from-plan`. Sync payloads are documented in `local-first-sync`; device registration in `push-notifications`. All require `Authorization: Bearer <access JWT>` + `apikey` and allow session recovery.

## Adding an endpoint

1. Confirm the route and payloads in `../koda-backend`.
2. Model request/response DTOs (`snake_case` `CodingKeys`) in the owning feature (`Models/DTOs/`) or Core when shared.
3. Add a static factory to `AuthAPI`/`KodaAPI` returning a typed `SupabaseRequest<Body, Response>`; choose `errorHandling` from the product flow.
4. Call it from a DataSource that injects only `HTTPService`; map DTOs to domain models in the repository (see `data-layer`).
5. Register the DataSource and repository in the assembly.
6. Test with a fake `HTTPTransport`: URL, method, headers (`apikey`, bearer present/absent), body encoding, success decoding, and error mapping to `KodaError` (status codes and GoTrue/PostgREST/function error bodies).

## Errors

`KodaErrorMapper` turns transport, decoding, cancellation, and HTTP failures into `KodaError`; `KodaErrorCenter` publishes the final failure according to the request's policy (`automatic`, `local`, `suppressed`). Cancellation is never shown to the user. A 401 on a recoverable request triggers one refresh and one retry.

## Logging

`HTTPLogger` redacts `authorization`, `apikey`, `password`, `refresh_token`, and token-like keys. Never log raw auth responses or household data.
