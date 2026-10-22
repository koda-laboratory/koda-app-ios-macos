---
name: xcode-build-fixer
description: Apply explicitly approved Koda Xcode build optimizations, validate the relevant scheme through the Xcode MCP, and re-benchmark with the original contract. Use only after an approved xcode-build-orchestrator plan or when the user names a specific build setting, script, source, or package fix to implement.
---

# Koda Xcode Build Fixer

Implement approved build-performance changes and prove their outcome.

## Required inputs

Use either:

- checked items in `.build-benchmark/optimization-plan.md`; or
- an explicit user instruction naming the exact optimization.

Do not infer approval from an analysis request. Apply one logical fix at a time so it remains reviewable and reversible.

## Project boundaries

- Project: `Koda.xcodeproj` at the repository root; multiplatform app target `Koda` (iPhone + Mac) built from the synchronized `Koda/` folder, plus `KodaWidgets` and `KodaTests`.
- Scheme/configurations: the single shared scheme `Koda` with `Debug` (development) and `Release` (TestFlight archives).
- Build configuration files: `Configuration/` (`Koda.xcconfig`, ignored `Koda.private.xcconfig`, version source `version.xcconfig`).
- Remote Swift packages are declared in the Xcode project; the lockfile is `Koda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

Never edit `.build/` or DerivedData. Never change a package pin merely to improve a benchmark.

## Workflow

1. Record the approved item, baseline artifact, affected files, risk, and expected wall-clock effect.
2. Resolve effective build settings with the same project, scheme, configuration, and destination as the baseline.
3. Apply the smallest durable change in source-controlled files.
4. For source changes under `Koda/`, load the relevant skill before editing:
   - SwiftUI: [`swiftui-expert-skill`](../swiftui-expert-skill/SKILL.md).
   - concurrency: [`swift-concurrency`](../swift-concurrency/SKILL.md).
   - third-party SDKs: [`ios-integrations`](../ios-integrations/SKILL.md).
5. Validate compilation with `BuildProject` through the Xcode MCP, following [`development`](../../rules/development.md). Use `GetBuildLog` and repeat until successful.
6. Run affected MCP tests and previews when the change crosses those surfaces.
7. Re-run [`xcode-build-benchmark`](../xcode-build-benchmark/SKILL.md) with the exact baseline contract.
8. Keep, revert, or escalate the change based on measured wall-clock behavior and non-performance requirements; report the decision.

`xcodebuild` is allowed for timing, diagnostics, package resolution, and `-showBuildSettings`. It is not the final build validation.

## Change categories

### Build settings and script phases

Use effective settings rather than assuming an unset value is wrong. `Debug` is the development configuration; `Release` is the distribution configuration. Treat values in [build-settings-best-practices.md](../xcode-project-analyzer/references/build-settings-best-practices.md) as candidates to verify and benchmark, not unconditional mandates.

For script phases (currently the SwiftLint phase running `scripts/swiftlint.sh`), add accurate inputs/outputs, configuration guards, or file lists only when they preserve the phase's purpose.

### Source compilation

Apply only diagnostics-backed changes. Use [fix-patterns.md](references/fix-patterns.md) as examples, then preserve existing architecture, localization, resources, and iPhone + Mac behavior. Code-quality refactors with no measured build benefit must be described as such.

### Package or module structure

The app code lives in the single multiplatform `Koda` target. Do not split it into modules or local packages, or change dependency pins, without an explicit proposal reviewed through [`ios-integrations`](../ios-integrations/SKILL.md).

## Evaluation and report

Compare clean, cached-clean when enabled, zero-change, and edit-rebuild metrics relevant to the user's workflow. A result inside benchmark noise is inconclusive. A tradeoff between build types must be presented for the user to decide; no setting is automatically retained despite a demonstrated regression.

Report:

- baseline and post-change medians, min/max, and variance;
- absolute and percentage wall-clock delta;
- files/settings changed;
- Xcode MCP scheme and final result;
- tests and previews validated;
- status: `Kept`, `Reverted`, `Blocked`, or `Inconclusive`.

Use the shared [recommendation format](../xcode-build-orchestrator/references/recommendation-format.md) when feeding results back to the orchestrator.
