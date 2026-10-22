---
name: ios-integrations
description: Integrate and maintain Koda platform services and Swift packages — Keychain (shared access group, data-protection keychain on macOS), WebKit, AVKit, and the declared packages (Swinject, GRDB.swift). Use when adding or updating a package, changing secure storage, or embedding web/media content. Not for plain SwiftUI (swiftui-expert-skill), backend endpoints (supabase-api), push (push-notifications), or GRDB sync (local-first-sync).
---

# Integrations

Read `AGENTS.md` and the `architecture` and `multiplatform` rules first. Koda deliberately has few dependencies: no analytics, ads, third-party sign-in, or animation SDKs, and no supabase-swift (the HTTP layer is in `Koda/Core/Api/`).

## Packages

Remote Swift packages are declared in `Koda.xcodeproj` (no `Package.swift`): `Swinject` (dependency injection) and `GRDB.swift` (local database). Sentry may be added later if needed. Resolved versions are committed in `Koda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. Add or update a package from Xcode and commit the updated `Package.resolved` with the change. Every package must support iOS and macOS.

## Placement

| Concern | Location |
| --- | --- |
| Keychain wrapper | `Koda/Core/Security/` (`Keychain`) |
| Keychain-backed storage | `Koda/Core/DataSources/Persistent/` (`KeychainStorableDataSource`) used by `SessionRepositoryImpl` |
| Biometric lock (planned) | `Koda/Core/Security/` (`BiometricLockService`, `LAContext`) |
| WebKit (if needed) | `Koda/Common/Presentation/Web/` |
| Video (if needed) | `AVKit` views in `Koda/Common/Presentation/` |

## References

- Read [auth-storage-media.md](references/auth-storage-media.md) for Keychain, biometrics, WebKit, and AVKit.

## Rules

- Platform SDKs live behind `Core` adapters registered in `Koda/Assembly/`. ViewModels never import a platform SDK.
- Configuration comes from `Configuration/Koda.xcconfig` and the ignored `Koda.private.xcconfig`, surfaced through `Info.plist`; never hard-code keys or commit secrets.
- Release WebViews, players, and observers with their view lifecycle.
- Never log keys, tokens, or personal data.

## Workflow

1. Read the existing adapter and its configuration.
2. Implement or update the `Core` adapter and its assembly registration; expose a use case to ViewModels when presentation needs it.
3. Verify on an iPhone simulator and on the Mac (signing-dependent features such as the shared Keychain group need a signed build).
4. Validate according to `development`.
