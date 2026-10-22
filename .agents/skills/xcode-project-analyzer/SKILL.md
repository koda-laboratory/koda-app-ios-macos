---
name: xcode-project-analyzer
description: Audit Koda's Xcode project, Debug/Release configurations, xcconfig files, schemes, build settings, script phases, and Swift package dependencies to find measured build-time improvements. Use for slow incremental builds, project-setting reviews, invalidation, script overhead, module variants, or package/plugin build costs. Recommendation-only unless the user explicitly approves changes.
---

# Koda Xcode Project Analyzer

Analyze project-level build costs that source refactoring alone will not solve.

## Scope and boundaries

- Open, inspect, and build `Koda.xcodeproj` at the repository root (multiplatform `Koda` app target for iPhone + Mac built from the synchronized `Koda/` folder, plus `KodaWidgets` and `KodaTests`).
- Audit the single shared scheme `Koda` with `Debug` and `Release`, on both the iOS simulator and macOS destinations.
- Inspect the xcconfig files under `Configuration/` (`Koda.xcconfig`, `version.xcconfig`) and the remote Swift packages declared in the project (`Package.resolved` under `Koda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`).
- Never edit `.build/` or DerivedData as an optimization shortcut.
- Follow [`development`](../../rules/development.md); CLI inspection is evidence collection, not final MCP validation.

## Workflow

1. Start from a fresh [`xcode-build-benchmark`](../xcode-build-benchmark/SKILL.md) artifact.
2. Resolve effective settings with `xcodebuild -showBuildSettings` for the measured project, scheme, configuration, and destination. Do not infer effective values solely from `project.pbxproj`.
3. Review scheme dependency order, target relationships, package resolution, build phases, inputs/outputs, and zero-change work.
4. Inspect timing for script phases (SwiftLint), module planning/emission, asset catalogs, package resolution and macro/plugin validation, codesigning, and validation.
5. Compare `Debug` (development) and `Release` (TestFlight archives), and check per-SDK settings (`[sdk=iphone*]`, `[sdk=macosx*]`) such as entitlements and provisioning.
6. Produce a recommendation-only checklist using the shared [recommendation format](../xcode-build-orchestrator/references/recommendation-format.md).

## Package rules

- Remote packages (Swinject, GRDB.swift) are declared in `Koda.xcodeproj`; their resolved versions live in the shared `Package.resolved`.
- Route dependency, package graph, or module-boundary proposals through [`ios-integrations`](../ios-integrations/SKILL.md).
- Never optimize the build number by disabling required product behavior (SwiftLint phase, dSYM generation for release) without presenting that as a deliberately isolated measurement.

## Reporting

For every finding include evidence, affected configuration/scheme, clean vs incremental impact, estimated wall-clock effect, confidence, risk, and approval requirement. Treat Xcode-internal work with no supported repository fix as `xcode-behavior` rather than promising a change.

Read:

- [project-audit-checks.md](references/project-audit-checks.md) for the detailed audit.
- [build-settings-best-practices.md](references/build-settings-best-practices.md) for candidate settings that still require effective-value inspection and measurement.
- [build-optimization-sources.md](references/build-optimization-sources.md) when verifying current Apple toolchain guidance.

Use [`xcode-build-fixer`](../xcode-build-fixer/SKILL.md) only after the user approves specific recommendations.
