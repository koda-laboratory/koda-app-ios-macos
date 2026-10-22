---
name: xcode-compilation-analyzer
description: Analyze Koda Swift compilation and type-checking hotspots from Xcode timing data, then produce a recommendation-only source optimization plan. Use when SwiftCompile, SwiftEmitModule, Planning Swift module, or type checking dominates measured Xcode builds. Do not use for unmeasured speculative refactoring.
---

# Koda Xcode Compilation Analyzer

Use measured evidence to locate Swift compiler work that affects developer wait time.

## Rules

- Start from a recent `.build-benchmark/` artifact or raw timing summary collected with [`xcode-build-benchmark`](../xcode-build-benchmark/SKILL.md).
- Keep project, scheme, configuration, and destination identical to the baseline.
- Prefer ad hoc compiler flags during analysis; do not persist them in Xcode settings.
- Rank wall-clock impact above cumulative parallel task time.
- Do not edit sources or settings without explicit approval.
- Follow [`development`](../../rules/development.md). Diagnostic `xcodebuild` runs do not replace the final Xcode MCP build after an approved implementation.

## Workflow

1. Determine whether compilation is on the critical path or merely parallel CPU work.
2. Inspect `SwiftCompile`, `SwiftEmitModule`, `Planning Swift module`, and per-file tasks in the raw logs.
3. Run the canonical diagnostics helper from the repository root:

   ```bash
   python3 .agents/skills/xcode-compilation-analyzer/scripts/diagnose_compilation.py \
     --project Koda.xcodeproj \
     --scheme Koda \
     --configuration Debug \
     --destination "platform=iOS Simulator,name=<same baseline simulator>" \
     --threshold 100 \
     --output-dir .build-benchmark
   ```

4. Inspect only the files supported by diagnostics. Separate source hotspots from module-planning or project-configuration problems.
5. Produce recommendations using the shared [recommendation format](../xcode-build-orchestrator/references/recommendation-format.md).

Use `--per-file-timing` or `--stats-output` only when threshold warnings are insufficient; these modes produce more data and slower diagnostic builds.

## Source changes

Any approved refactor must preserve behavior, architecture, and iPhone + Mac support:

- SwiftUI: read [`swiftui-expert-skill`](../swiftui-expert-skill/SKILL.md).
- Concurrency changes: read [`swift-concurrency`](../swift-concurrency/SKILL.md).

Do not split the `Koda` app target into modules or local packages merely to reduce compile time. Route package-graph recommendations through [`ios-integrations`](../ios-integrations/SKILL.md) and require an explicit design decision.

## Reporting

For each finding include evidence, file/module, likely wall-clock impact, confidence, platform risk, and approval requirement. If project settings or scripts are the cause, hand off to [`xcode-project-analyzer`](../xcode-project-analyzer/SKILL.md).

Read [code-compilation-checks.md](references/code-compilation-checks.md) only after compilation has been shown to be relevant. Use the Apple-aligned sources owned by [`xcode-project-analyzer`](../xcode-project-analyzer/references/build-optimization-sources.md) when current toolchain behavior needs verification.
