---
name: ios-app-walkthrough
description: Orchestrate day-to-day work in the native Koda app (iPhone + Mac). Use to select the right local skills, place Swift code and resources correctly, and choose validation from feature development through delivery. Not for writing the code of a single layer once the owning skill is known.
---

# Koda app walkthrough

Route work in this repository to the right rules, skills, and locations.

## 1. Read the mandatory context

Read `AGENTS.md` and the seven rules in `.agents/rules/`: `development`, `architecture`, `presentation-architecture`, `swiftui-structure`, `keyboard-dismissal`, `multiplatform`, and `local-first`. Product decisions live in `../PLAN.md`; the backend contract lives in `../koda-backend`.

## 2. Choose the smallest set of skills

| Work | Skill |
| --- | --- |
| Screens, components, ViewModels, forms | `application-layer` |
| Use cases, services, business rules | `domain-layer` |
| Repositories, DataSources, DTOs, Keychain/UserDefaults | `data-layer` |
| GRDB, outbox, SyncEngine, conflicts | `local-first-sync` |
| Adding or changing a Supabase endpoint | `supabase-api` |
| Design tokens, components, look & feel | `koda-design-system` |
| Routes, tabs/sidebar, sheets, Mac commands, deep links, transitions | `navigation-layer` |
| Mac windows, resizing, scenes | `app-resizability` |
| SwiftUI APIs, state, layout, performance | `swiftui-expert-skill`, `swiftui-specialist`, `swiftui-whats-new-27` |
| Design review, HIG compliance, control and icon sizing | `apple-design` |
| Swift concurrency | `swift-concurrency` |
| App Intents, Siri, Spotlight, widgets, controls | `app-intents-specialist`, `app-intents-whats-new-27` |
| APNs registration, silent push, background sync | `push-notifications` |
| Keychain, WebKit, AVKit | `ios-integrations` |
| SF Symbols and app icon | `ios-icons` |
| Strings and permissions | `ios-localization` |
| Unit and UI tests | `ios-testing` |
| Scripted UI flows and screenshots | `ios-ui-automation` |
| Checking behavior on a simulator, device, or the Mac | `device-interaction` |
| Signing, versioning, fastlane, TestFlight, CI | `ios-deployment` |
| Build performance and settings | `xcode-build-orchestrator` and the other `xcode-*` skills, `audit-xcode-security-settings` |
| Commits | `commit` |

For a feature slice spanning several layers, use the `feature-builder` agent (`.agents/feature-builder.md`).

## 3. Plan before editing

List the UI states (including offline and pending-sync), intents, local tables and outbox mapping, API contract (if any), session behavior, navigation outcomes on iPhone and Mac, strings, and widget/intent impact. Identify which already exist.

## 4. Implement inside-out

Record/DTO → DataSource → repository protocol + Impl + assembly registration → use case → ViewModel (state/intent/form) → view + components → navigation → strings and symbols → previews (iPhone + Mac) → tests.

## 5. Validate and record

Follow `development`: Xcode MCP builds of scheme `Koda` for an iPhone simulator and My Mac, focused `KodaTests`, previews, and a simulator/Mac check for UI work.

## Placement quick reference

- Reusable UI used by two or more features: `Koda/Common/Presentation/<Type>/`. Design tokens: `Koda/Common/Theme/`.
- Cross-feature use cases: `Koda/Core/UseCases/`; long-lived shared state: `Koda/Core/Services/`; shared domain models: `Koda/Core/Models/`.
- HTTP and Supabase provider: `Koda/Core/Api/` (`Providers/Supabase/`). Errors: `Koda/Core/Error/` (`KodaError`, `KodaErrorCenter`, `KodaErrorMapper`). Logging: `Koda/Core/Logging/`.
- Keychain: `Koda/Core/Security/`; storage data sources: `Koda/Core/DataSources/`; session repository: `Koda/Core/Repositories/`.
- Routes and router: `Koda/Core/Navigation/`. Platform abstractions (the only `#if os` outside `App/`): `Koda/Core/Platform/`.
- Planned: `Koda/Core/Database/` (GRDB), `Koda/Core/Sync/` (SyncEngine), `Koda/Core/Notifications/`, `Koda/Core/DeepLink/`, `Koda/Intents/`.
- App entry and per-platform delegates: `Koda/App/` (`KodaApp.swift`, `iOS/AppDelegate+iOS.swift`, `macOS/AppDelegate+macOS.swift`).
- Dependency registration: `Koda/Assembly/`. Extensions: `Koda/Extensions/`. Resources: `Koda/Resources/`.
- Widgets: `KodaWidgets/`. Tests: `KodaTests/`.
- Build configuration: `Configuration/` (`Koda.xcconfig`, `version.xcconfig`, `Info.plist`, entitlements).
