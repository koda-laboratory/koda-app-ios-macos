---
name: ios-testing
description: Add and run Koda tests with Swift Testing in the KodaTests target — unit tests for ViewModels, use cases, repositories, DTO decoding, the HTTP stack and single-flight session recovery, error mapping, GRDB migrations/outbox, and the SyncEngine — plus XCUITest smoke tests when needed. Use when behavior changes, when fixing a bug that needs a regression test, or when asked to test. Not for scripted UI flows (ios-ui-automation) or manual checks (device-interaction).
---

# Testing

## Target

`KodaTests` is a Swift Testing unit-test bundle hosted by the `Koda` app, in the shared scheme `Koda`, with a synchronized folder `KodaTests/` at the repository root. Use `@testable import Koda`. The fastlane `test` lane (`ios` and `mac`) runs it.

## Layout

```text
KodaTests/
  Core/Api/            SupabaseRequest building/decoding, HTTPService, HTTPSessionRecovery (single-flight)
  Core/Error/          KodaErrorMapper, KodaError actions and presentation
  Core/Database/       migrations, records, outbox written in the same transaction (planned)
  Core/Sync/           SyncEngine push/pull with a fake transport, conflict application (planned)
  Features/<Feature>/  <Name>ViewModelTests, use case, repository, and DTO decoding tests
  Support/             fakes (HTTPTransport, repositories, services), fixtures
```

Fakes implement the protocols (`FakeHTTPTransport: HTTPTransport`, `FakeShoppingRepository: ShoppingRepository`).

## What to test

| Change | Test |
| --- | --- |
| ViewModel state machines, intents, forms | `@MainActor` tests that `await viewModel.send(...)` and assert `state`/`form` |
| Use case orchestration and error policy | use case with fake repositories and services |
| DTO decoding and mapping | decoding inline Supabase JSON (`snake_case`) through the shared decoder |
| HTTP, errors, session recovery | `Core/Api` and `Core/Error` tests with a fake `HTTPTransport`; concurrent 401s trigger exactly one refresh |
| GRDB repositories | in-memory `DatabaseQueue`: row + outbox entry committed together, observation emits updates |
| Sync | push batches of 100, rejected mutations, pull applying tombstones without creating outbox, cursor advance |
| Pure rules (recipe expansion, cycles, aggregation) | parameterized `@Test(arguments:)` tables |

Test behavior, not implementation. For concurrency semantics (cancellation, ordering, clocks) read `swift-concurrency` and its `references/testing.md`.

## Commands

- Xcode MCP: `GetTestList`, then `RunSomeTests` for focused runs or `RunAllTests` (required by `development` when relevant tests exist).
- CLI (diagnostics/CI): `xcodebuild test -project Koda.xcodeproj -scheme Koda -destination 'platform=iOS Simulator,name=iPhone 17'` and `-destination 'platform=macOS'`.
- fastlane: `bundle exec fastlane ios test`, `bundle exec fastlane mac test`.

## Rules

- Never hit the real Supabase project from tests; inject fakes through initializers or preview/test assemblies. There is only one (production) environment.
- No real user data, tokens, or emails in fixtures.
- A bug fix includes a regression test that fails before the fix.
- Keep tests deterministic: injected clocks for debounce and lock timeouts; avoid real sleeps except tiny suspension points when proving single-flight behavior.
- The app skips bootstrap when hosted for tests or previews; keep launch work behind that check.
