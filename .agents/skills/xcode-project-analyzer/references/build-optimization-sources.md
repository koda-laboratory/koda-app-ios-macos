# Apple Build-Optimization Sources

Use these primary sources when current Xcode behavior or a recommendation needs verification. Browse the live page before relying on toolchain-sensitive details.

## Incremental builds

- [Improving the speed of incremental builds](https://developer.apple.com/documentation/xcode/improving-the-speed-of-incremental-builds)

Relevant guidance:

- Measure before optimizing with Xcode's timing summary or `xcodebuild -showBuildTimingSummary`.
- Keep target dependencies accurate so the build system can schedule work correctly.
- Give run scripts accurate inputs and outputs.
- Investigate unexpectedly repeated tasks during incremental builds.

## Source compilation

- [Improving build efficiency with good coding practices](https://developer.apple.com/documentation/xcode/improving-build-efficiency-with-good-coding-practices)

Relevant guidance:

- Reduce exported and bridging surfaces when evidence points to them.
- Give the compiler explicit information when inference becomes expensive.
- Keep C/Objective-C imports modular when those languages are present.

## Explicit modules

- [Building your project with explicit module dependencies](https://developer.apple.com/documentation/xcode/building-your-project-with-explicit-module-dependencies)
- [Demystify explicitly built modules (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10171/)

Relevant guidance:

- Explicit module tasks improve scheduling visibility and parallelism.
- Repeated module variants can result from inconsistent compiler options.
- Use timing summaries and build logs to identify actual duplication before changing settings.

## Current build settings and toolchain behavior

- [Xcode build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Xcode 26 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes)

Verify current defaults here before recommending overrides. In Xcode 26, Swift explicit modules are the default for supported targets and compilation caching is available as an opt-in setting. Local benchmark evidence still decides whether an optional performance setting benefits Koda.
