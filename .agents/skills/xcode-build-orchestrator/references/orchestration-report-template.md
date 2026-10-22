# Koda Xcode Build Optimization Report

Use this structure to consolidate benchmark evidence and specialist findings. Keep the analysis and execution phases separate.

```markdown
# Koda Xcode Build Optimization Plan

## Build Contract
- Project: `Koda.xcodeproj`
- Scheme / configuration: `Koda` / `Debug`
- Destination: `<available simulator>`
- Package resolution: `Package.resolved` commit or hash
- Xcode/macOS: `<versions>`
- Baseline artifact: `.build-benchmark/<artifact>.json`

## Baseline

| Metric | Median | Min | Max | Runs |
| --- | ---: | ---: | ---: | ---: |
| Clean | X.Xs | X.Xs | X.Xs | 3 |
| Cached clean | X.Xs | X.Xs | X.Xs | 3 |
| Zero-change | X.Xs | X.Xs | X.Xs | 3 |
| Edit-rebuild | X.Xs | X.Xs | X.Xs | 3 |

State which optional rows were not measured. Timing-summary categories are cumulative task time, not developer wait time.

## Project Audit
- Effective Debug/Release settings:
- Scheme and dependency findings:
- Script-phase findings:
- Package/module findings:

## Compilation Diagnostics
- Artifact:
- Critical-path conclusion:
- Ranked hotspots:

## Prioritized Recommendations

### 1. <title>
- Wait-time impact:
- Actionability:
- Platform scope:
- Evidence:
- Affected files/settings:
- Confidence:
- Risk:
- Verification required:

## Approval Checklist
- [ ] **1. <title>** — expected impact / risk / platform scope

Stop here until the user explicitly approves items.

## Execution Report

### Validation
- Xcode MCP scheme/result:
- Tests/previews:
- Test and preview checks:

### Changes
| Change | Before | After | Status |
| --- | ---: | ---: | --- |
| <item> | X.Xs | X.Xs | Kept / Reverted / Blocked / Inconclusive |

### Final Result
- Clean:
- Cached clean:
- Zero-change:
- Edit-rebuild:
- Net wall-clock effect:
- Benchmark confidence:
- Remaining findings:
```

Do not include community-project links, copied benchmark claims, or recommendations that were not supported by Koda evidence. When the destination or resolved packages differ, report the runs as separate scopes instead of a before/after comparison.
