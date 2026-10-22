# Koda Project Audit Checks

Use this checklist after a benchmark points to project configuration, planning, scripts, resources, or package work.

## Project and scheme

- Build `Koda.xcodeproj` at the repository root.
- Use scheme `Koda` with `Debug` or `Release`, and name the destination (iOS simulator or macOS).
- Confirm dependency order and actual target dependencies.
- Keep the same available simulator and resolved packages used by the baseline.

## Script phases

- Identify every script phase and whether it runs in Debug and Release and for which targets/SDKs.
- Check declared inputs, outputs, `.xcfilelist` use, and dependency analysis.
- Flag scripts that touch source timestamps without content changes.
- The `Koda` target runs `scripts/swiftlint.sh` as a build phase; measure it before proposing input/output lists or configuration guards, and keep linting in the developer workflow.

## Incremental and zero-change overhead

- Use timing summaries and raw logs to inspect planning, scripts, codesigning, validation, `CopySwiftLibs`, and metadata extraction.
- When tasks rerun unexpectedly, use current Xcode task-backtrace/build-log facilities when available.
- Do not infer a repository fix for Xcode-internal tasks without supported evidence; classify them as `xcode-behavior`.

## Build settings

- Resolve effective values through `xcodebuild -showBuildSettings`; `project.pbxproj` and `.xcconfig` inspection alone is incomplete.
- Audit Debug as development and Release as distribution, including per-SDK overrides.
- Use [build-settings-best-practices.md](build-settings-best-practices.md) as candidates, not mandates.
- Check for unnecessary module variants caused by differing compiler flags or conditions.

## Packages and modules

- Inspect the package references in `Koda.xcodeproj`, the shared `Package.resolved`, and build-log package tasks (resolution, macro and plugin validation).
- Check whether dependencies or plugins invalidate builds or produce duplicate variants.
- Before suggesting a new target, local package, or module split, account for resources, access control, the App Group shared with `KodaWidgets`, and the single multiplatform `Koda` app target.
- Route approved package changes through `ios-integrations`.

## Resources

- Inspect `CompileAssetCatalog` only when it is material to wall-clock time.
- `Koda/Resources/Assets.xcassets` holds the app icon and the Koda color sets used by `KodaColor`; do not split or relocate it without checking `koda-design-system` and `ios-icons`.
- Treat localization and bundle changes as product behavior, not a build-only refactor.

## Prioritization

- High: measured serial bottlenecks, invalidating scripts, or redundant module variants on the critical path.
- Medium: meaningful planning, resource, codesigning, or package overhead with a plausible repository fix.
- Low: cleanup or explicit default settings without evidence of wall-clock impact.

Every recommendation must state its evidence, configuration, measurement scope, estimated wall-clock impact, confidence, risk, and approval requirement.
