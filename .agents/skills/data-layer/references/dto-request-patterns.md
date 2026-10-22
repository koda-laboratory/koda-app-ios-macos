# DTO and Request Patterns

## Separate transport models by direction

Request DTOs are `Encodable`; response DTOs are `Decodable`. Add `Sendable` and `Equatable` when their usage requires them. Supabase uses `snake_case` JSON:

```swift
struct PasswordGrantBodyDTO: Encodable, Sendable {
    let email: String
    let password: String
}

struct SupabaseSessionDTO: Decodable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let expiresAt: Int?
    let user: SupabaseUserDTO

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case user
    }
}
```

Build domain models from DTOs with conversion initializers at the repository boundary.

## Typed SupabaseRequest declarations

Reference: `Koda/Core/Api/Providers/Supabase/AuthAPI.swift`

```swift
static func refresh(refreshToken: String) -> SupabaseRequest<RefreshGrantBodyDTO, SupabaseSessionDTO> {
    SupabaseRequest(
        path: "auth/v1/token",
        method: .post,
        queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
        body: RefreshGrantBodyDTO(refreshToken: refreshToken),
        errorHandling: .suppressed,
        allowsSessionRecovery: false,
        sendsAuthorization: false
    )
}
```

The exact initializer is defined in `SupabaseRequest.swift`; read it before adding an endpoint. Principles:

- Generic parameters make body and response contracts explicit; the base URL defaults to `SupabaseEnvironment` and stays injectable for tests.
- Auth endpoints never trigger session recovery (`allowsSessionRecovery: false`) and do not send the stale bearer token.
- Choose `errorHandling` from the product flow; do not suppress errors solely to make a call site simpler.
- Product endpoints of the Edge Function `api` live under `/functions/v1/api/...` (planned `KodaAPI.swift`).

## Headers

`apikey` (publishable key) is always sent; `Authorization: Bearer <access token>` is added by the shared header provider for authenticated requests (`SupabaseHeaders`). Do not add headers ad hoc at call sites and never clear session state to manipulate headers.

## Dates

- Timestamps (`timestamptz`) decode to `Date` through the shared decoder configuration; do not parse strings in each DTO or ViewModel.
- Calendar days (`date` columns such as `meal_plan_entries.date`, `consumptions.eaten_on`) are day values in the household time zone (`Europe/Madrid`), not instants.

## Query values

Encode query parameters with `URLQueryItem`s built by the request type (for example `cursor` and `limit` for `/sync/pull`). Do not concatenate query strings or percent-escape values at call sites. Keep the sync cursor opaque.

## Anti-patterns

- DTOs conforming to SwiftUI protocols or exposing localized presentation text.
- Domain models whose stored properties mirror transport-only fields (`expires_in`).
- ViewModels constructing request DTOs.
- Raw dictionary bodies when a typed DTO can describe the contract (the sync `fields` payload is the deliberate exception: it is a JSON object per table row).
- Per-endpoint `JSONDecoder` date parsing outside shared request infrastructure.
- Logging request bodies with passwords or tokens.
