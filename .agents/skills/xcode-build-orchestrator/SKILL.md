---
name: xcode-build-orchestrator
description: "Run Koda's end-to-end Xcode build optimization workflow: benchmark, analyze compilation and project evidence, present an approval plan, apply approved fixes, validate through the Xcode MCP, and re-benchmark. Use for requests to speed up builds, perform a full build audit, or compare and improve the Debug developer workflow on iPhone simulator and Mac."
---

# Koda Xcode Build Orchestrator

Coordinate the specialist skills without duplicating their instructions or resources.

## Non-negotiable rules

- Developer wall-clock wait time is the success metric.
- Analyze and recommend before changing product or build files.
- Preserve an evidence trail under `.build-benchmark/`.
- Require explicit approval for every implementation item.
- Reuse identical benchmark inputs before and after a change.
- After implementation, complete the Xcode MCP validation required by [`development`](../../rules/development.md). Benchmark and diagnostic `xcodebuild` runs do not replace it.

## Koda build contract

Use `Koda.xcodeproj` (repository root), target `Koda`, and one of these scheme/configuration pairs:

| Purpose | Scheme | Configuration |
| --- | --- | --- |
| Development (default) | `Koda` | `Debug` |
| TestFlight archives | `Koda` | `Release` |

Koda has a single environment and one shared scheme. Measure the iOS simulator destination (`generic/platform=iOS Simulator`) and My Mac (`platform=macOS`) as separate scopes. Keep one available destination constant and the same resolved package versions across compared runs.

## Phase 1: analyze and propose

Only benchmark artifacts and the optimization plan may be created in this phase.

1. Clarify whether the pain is clean builds, zero-change builds, edit-rebuilds, package resolution, or a combination.
2. Read and run [`xcode-build-benchmark`](../xcode-build-benchmark/SKILL.md). If the baseline fails, diagnose the current state; do not cherry-pick, rewrite, or otherwise mutate history to manufacture a buildable baseline.
3. Reject unreliable comparisons: mismatched commands or destinations, failed samples, missing timing categories, or min/max spread greater than 20% of the median without enough repetitions.
4. Apply the specialist whose scope matches the evidence:
   - [`xcode-compilation-analyzer`](../xcode-compilation-analyzer/SKILL.md) for Swift/type-checking work.
   - [`xcode-project-analyzer`](../xcode-project-analyzer/SKILL.md) for settings, scripts, planning, schemes, or module variants.
   - [`ios-integrations`](../ios-integrations/SKILL.md) for dependency or package-graph proposals.
5. Merge findings using [recommendation-format.md](references/recommendation-format.md), ordered by expected wall-clock improvement and confidence.
6. Generate or write `.build-benchmark/optimization-plan.md` using [orchestration-report-template.md](references/orchestration-report-template.md).
7. Present a concise approval checklist and stop before implementation.

## Phase 2: execute and verify

Start only after the user explicitly approves recommendations.

1. Read the approved plan and invoke [`xcode-build-fixer`](../xcode-build-fixer/SKILL.md).
2. Apply one logical fix at a time and keep unrelated product behavior unchanged.
3. Run the required `BuildProject` through the Xcode MCP with the relevant scheme. Use `GetBuildLog` to resolve failures and repeat until successful.
4. Run affected tests or previews through the MCP when the change warrants them.
5. Re-run the benchmark with the exact baseline contract.
6. Append before/after wall-clock medians, absolute/percentage deltas, variance, platform-validation results, and retained/reverted items to the plan.

Do not claim improvement when the post-change median remains inside a noisy baseline range. If cumulative compiler work drops but wall-clock time does not, state that plainly.

## Canonical commands

Benchmarking and compilation diagnostics are owned by their specialist skills; run their scripts from those skill directories. To render the combined report:

```bash
python3 .agents/skills/xcode-build-orchestrator/scripts/generate_optimization_report.py \
  --benchmark .build-benchmark/<benchmark>.json \
  --recommendations .build-benchmark/<recommendations>.json \
  --diagnostics .build-benchmark/<diagnostics>.json \
  --output .build-benchmark/optimization-plan.md
```

Only pass artifacts that were collected with the same build contract.

## Resources

- [recommendation-format.md](references/recommendation-format.md) owns the shared recommendation schema.
- [orchestration-report-template.md](references/orchestration-report-template.md) owns the plan and execution-report structure.
- [`xcode-build-benchmark/references/benchmark-artifacts.md`](../xcode-build-benchmark/references/benchmark-artifacts.md) owns the measurement artifact contract.
- [`xcode-project-analyzer/references/build-settings-best-practices.md`](../xcode-project-analyzer/references/build-settings-best-practices.md) owns build-setting guidance.
