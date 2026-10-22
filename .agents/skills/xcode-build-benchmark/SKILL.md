---
name: xcode-build-benchmark
description: Benchmark Koda Xcode clean, cached-clean, zero-change, and edit-rebuild times with repeatable inputs and `.build-benchmark/` artifacts. Use when measuring Xcode build duration, establishing a baseline, or comparing build performance before and after a change. Uses `xcodebuild` only as a measurement instrument; it never replaces the required Xcode MCP validation.
---

# Koda Xcode Build Benchmark

Produce repeatable wall-clock measurements before recommending build optimizations.

## Fixed project context

- Project: `Koda.xcodeproj` at the repository root.
- Scheme/configuration: `Koda` / `Debug` (default) or `Koda` / `Release`.
- Targets: `Koda` (iPhone + Mac), `KodaWidgets`, `KodaTests`.
- Destinations: measure `generic/platform=iOS Simulator` and `platform=macOS` separately.
- Choose one available iOS Simulator destination and keep it unchanged across compared runs. Do not hardcode a device that is not installed.
- Remote Swift packages resolve into DerivedData; keep the same resolved `Package.resolved` across compared runs.

Follow the CLI/MCP boundary in [`development`](../../rules/development.md): `xcodebuild` is permitted for timing data, but does not satisfy final implementation validation.

## Workflow

1. Record project, scheme, configuration, destination, Xcode version, and any cache-affecting flags.
2. Run one validation/warm-up cycle.
3. Run three clean builds.
4. When compilation caching is enabled, run three cached-clean builds.
5. Run three zero-change builds to measure fixed overhead.
6. When edit-loop performance matters, additionally touch a representative source file and run three incremental builds.
7. Save JSON and raw logs under `.build-benchmark/`.
8. Report median, min, max, variance, and the largest timing-summary categories. Treat category totals as cumulative task time, not wall-clock time.

Do not change product or project files during measurement. Stop if a run fails instead of mixing failed and successful samples.

## Command

Run the canonical helper from the repository root:

```bash
python3 .agents/skills/xcode-build-benchmark/scripts/benchmark_builds.py \
  --project Koda.xcodeproj \
  --scheme Koda \
  --configuration Debug \
  --destination "platform=iOS Simulator,name=<available simulator>" \
  --output-dir .build-benchmark
```

Add `--touch-file Koda/<path>.swift` only when measuring a representative edit-rebuild loop. The helper stores local paths and machine information, so benchmark artifacts remain untracked.

## Handoff

- Swift compiler or type-checking hotspots: [`xcode-compilation-analyzer`](../xcode-compilation-analyzer/SKILL.md).
- Schemes, settings, scripts, or invalidation: [`xcode-project-analyzer`](../xcode-project-analyzer/SKILL.md).
- Package graph or third-party dependency concerns: [`ios-integrations`](../ios-integrations/SKILL.md).
- Full recommend-approve-fix workflow: [`xcode-build-orchestrator`](../xcode-build-orchestrator/SKILL.md).

## Resources

- Read [benchmarking-workflow.md](references/benchmarking-workflow.md) before collecting a baseline.
- Read [benchmark-artifacts.md](references/benchmark-artifacts.md) when consuming or comparing artifacts.
- Validate JSON artifacts against [build-benchmark.schema.json](schemas/build-benchmark.schema.json) when changing the helper or artifact contract.
