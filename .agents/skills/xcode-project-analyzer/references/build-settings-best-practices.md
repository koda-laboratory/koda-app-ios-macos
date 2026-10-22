# Koda Build-Setting Candidates

Use this reference when effective build settings and timing evidence indicate a configuration-level opportunity. These values are candidates to inspect and benchmark, not unconditional changes.

## Configuration mapping

| Purpose | Scheme | Configuration |
| --- | --- | --- |
| Development | `Koda` | `Debug` |
| TestFlight archives (fastlane) | `Koda` | `Release` |

Resolve effective values with `xcodebuild -showBuildSettings` against `Koda.xcodeproj`, for both `-destination 'generic/platform=iOS Simulator'` and `-destination 'platform=macOS'`. `Debug` is the development workflow and takes priority in a build-time audit.

## Debug

### Swift compilation mode

- Key: `SWIFT_COMPILATION_MODE`
- Candidate: `singlefile`, or unset when the current Xcode default resolves to incremental compilation.
- Why: recompiles changed files instead of the complete module.
- Risk: low, but verify effective value and edit-rebuild behavior.

### Swift optimization

- Key: `SWIFT_OPTIMIZATION_LEVEL`
- Candidate: `-Onone`.
- Why: avoids optimization passes during development.
- Risk: low.

### Active architecture only

- Key: `ONLY_ACTIVE_ARCH`
- Candidate: `YES` for local simulator/device iteration.
- Why: avoids compiling architectures that the selected destination does not use.
- Risk: low for development; do not carry into production archives.

### Debug information

- Key: `DEBUG_INFORMATION_FORMAT`
- Candidate: `dwarf`.
- Why: avoids local dSYM generation when it is not required.
- Risk: low; retain symbolication requirements for any development crash workflow that needs dSYMs.

### Testability

- Key: `ENABLE_TESTABILITY`
- Candidate: `YES` when tests use `@testable import`.
- Why: correctness requirement, not a performance optimization.
- Risk: changing it may break tests; do not disable merely for timing.

### Eager linking

- Key: `EAGER_LINKING`
- Candidate: evaluate for Debug.
- Why: may overlap linking with compilation.
- Risk: low to medium; keep only after a stable benchmark confirms value with the current Xcode toolchain.

## Release

### Swift compilation and optimization

- `SWIFT_COMPILATION_MODE`: normally `wholemodule` for production optimization.
- `SWIFT_OPTIMIZATION_LEVEL`: normally `-O` or `-Osize` according to product requirements.
- `ONLY_ACTIVE_ARCH`: `NO` for archives/distribution.
- `DEBUG_INFORMATION_FORMAT`: `dwarf-with-dsym` for production crash symbolication.
- `ENABLE_TESTABILITY`: normally `NO` unless a deliberate production-like testing workflow requires it.

Production settings prioritize output correctness, supported architectures, and symbolication over local build speed.

## All configurations

### Compilation caching

- Key: `COMPILATION_CACHE_ENABLE_CACHING`.
- Candidate: evaluate `YES` using cold-clean, cached-clean, and edit-rebuild measurements.
- Why: Xcode can reuse compilation results for identical inputs, especially across clean builds and branch switching.
- Risk: low, but local benefit varies; never quote results copied from another project as Koda evidence.

### Explicit Swift modules

- Key: `SWIFT_ENABLE_EXPLICIT_MODULES`.
- Xcode 26 behavior: enabled by default for supported Swift targets.
- Action: inspect module variants and effective values before adding an override. Do not use the old private `_EXPERIMENTAL_SWIFT_EXPLICIT_MODULES` setting.
- Risk: medium when overriding the toolchain default; benchmark and validate package compatibility.

### Clang modules and integrated driver

- `CLANG_ENABLE_MODULES`: normally `YES` when C/Objective-C modules are present.
- `SWIFT_USE_INTEGRATED_DRIVER`: verify only when logs or migrated settings indicate it is disabled; modern Xcode normally manages this behavior.

Do not add explicit settings merely to restate current defaults without evidence that doing so improves correctness, determinism, or measured performance.

## Cross-target and package consistency

Inspect drift in:

- `SWIFT_COMPILATION_MODE`
- `SWIFT_OPTIMIZATION_LEVEL`
- `ONLY_ACTIVE_ARCH`
- `DEBUG_INFORMATION_FORMAT`
- `OTHER_SWIFT_FLAGS`
- compilation conditions that cause necessary module variants

Remote packages may be built with settings that differ from the `Koda` app target; a difference is not automatically a defect. Flag only redundant variants supported by the build log.

## Report format

For every configuration show the effective value, candidate value, evidence, expected wall-clock effect, risk, and benchmark requirement:

```markdown
### Debug
- [x] `SWIFT_OPTIMIZATION_LEVEL`: `-Onone`
- [ ] `COMPILATION_CACHE_ENABLE_CACHING`: unset; candidate `YES`, benchmark required

### Release
- [x] `DEBUG_INFORMATION_FORMAT`: `dwarf-with-dsym`
```

Do not classify Swift language-migration settings such as `SWIFT_STRICT_CONCURRENCY`, `SWIFT_UPCOMING_FEATURE_*`, or `SWIFT_APPROACHABLE_CONCURRENCY` as build-performance defects.
