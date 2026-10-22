---
description: Validate Koda product changes through the Xcode MCP on iPhone and Mac before completion
alwaysApply: true
---

# Development validation

Every product feature or implementation change must be validated through the Xcode MCP before it is reported as complete, on **both** platforms Koda ships: iPhone and Mac.

This rule applies to changes in product code, resources, tests, dependencies, and build or runtime configuration. Documentation-only work and changes limited to agent instructions, skills, or rules are exempt unless they also affect the product build or runtime.

## Required Xcode MCP workflow

1. Ensure Xcode has `Koda.xcodeproj` (repository root) open.
2. Use the Xcode MCP window-listing tool to identify the tab for that project. Do not assume a stale tab or identifier.
3. Select the shared scheme `Koda` (the only scheme; configurations `Debug` and `Release`). The `Koda` target also runs `scripts/swiftlint.sh` as a build phase, so lint violations surface in the same build.
4. Run the Xcode MCP project-build tool (`BuildProject`) for an iPhone simulator run destination.
5. Switch the run destination to `My Mac` and run `BuildProject` again. A change is not complete until both builds succeed; `#if os(...)` code paths only compile on their own platform.
6. If a build fails, inspect the MCP build log (`GetBuildLog`) and Xcode issues, fix the underlying source or configuration, and repeat until both succeed.
7. Report the scheme, both destinations, and the final MCP build results in the handoff.

An implementation is not complete while a required MCP build is failing or has not run.

## Xcode build-performance measurements

The `xcode-build-*` skills may use `xcodebuild` for repeatable timing, compiler diagnostics, package resolution, and effective build-setting inspection. Those CLI runs are measurement evidence only and never satisfy the required MCP builds above.

Use `Koda.xcodeproj` with scheme `Koda` and configuration `Debug` (or `Release` when measuring archive-like builds), with `-destination 'generic/platform=iOS Simulator'` or `-destination 'platform=macOS'`.

## Tests and UI checks

- When behavior changes and relevant tests exist, discover them with the Xcode MCP test-listing tool and run the focused tests (`RunSomeTests`) or the full `KodaTests` suite (`RunAllTests`) as appropriate.
- For SwiftUI work with a usable preview, render the iPhone and the Mac previews through the Xcode MCP (`RenderPreview`) and inspect the result.
- For user-visible behavior, run the affected flow on an iPhone simulator (or device) and on the Mac, in `en` and `es` when text changes. Follow [`device-interaction`](../skills/device-interaction/SKILL.md), [`ios-testing`](../skills/ios-testing/SKILL.md), or [`ios-ui-automation`](../skills/ios-ui-automation/SKILL.md) when they apply.
- Before committing Swift changes, `swift format lint --strict` must pass for the staged files (the `.githooks/pre-commit` hook enforces it).
- Never claim a build, test, preview, or visual check that was not actually executed in the current session; name any step that could not run and why.

## When the Xcode MCP is unavailable

Do not silently replace the MCP validation with `xcodebuild`. The explicitly permitted performance measurements above are not a fallback build.

First diagnose the connection: confirm Xcode is running, the correct project is open, the scheme is shared, and the `xcode` MCP server is available. If it still cannot run, clearly report the blocker and ask the user before using `xcodebuild` as a fallback (both `generic/platform=iOS Simulator` and `platform=macOS`, with `CODE_SIGNING_ALLOWED=NO` when signing assets are absent). A CLI fallback does not count as the required MCP validation and must be identified as such.
