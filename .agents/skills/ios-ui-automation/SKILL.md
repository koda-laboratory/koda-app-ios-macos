---
name: ios-ui-automation
description: Create and run Koda UI smoke tests (XCUITest or Maestro on the iOS Simulator) and capture localized iPhone and Mac screenshots. Uses bundle id com.kodalabs.app and stable accessibility identifiers. Use when validating critical UI flows, navigation, offline behavior, or visual regressions. Not for unit tests (ios-testing) or ad-hoc manual checks (device-interaction).
---

# UI automation

## Layout

No UI flows are committed yet. When they are added:

```text
maestro/                      # iPhone simulator flows (Maestro does not drive macOS apps)
  config.yaml
  flows/
    login.yaml
    shopping-offline.yaml
    planning.yaml
  subflows/
    launch-clean.yaml
KodaUITests/                  # XCUITest target for iPhone and Mac smoke tests (optional)
screenshots/                  # ignored by .gitignore
```

## References

- Read [maestro-flows.md](references/maestro-flows.md) when writing or running flows.
- Read [locale-switching.md](references/locale-switching.md) for `en`/`es` runs and screenshots.
- Read [build-state-recovery.md](references/build-state-recovery.md) when installs, simulators, or app state get stuck.
- Read [platform-quirks.md](references/platform-quirks.md) for SwiftUI accessibility, sheets, keyboard, and Mac specifics.

## Rules

- Select elements by `.accessibilityIdentifier(...)`. Identifiers follow `<feature>.<element>` (`auth.email`, `auth.submit`, `shopping.quick-add`, `shopping.entry.<id>`, `tab.today`); keep them stable across refactors.
- Icon-only controls also need a localized accessibility label.
- There is a single real Supabase environment: authenticated flows read `KODA_TEST_EMAIL`/`KODA_TEST_PASSWORD` from the environment and must use a dedicated test household provided by the user; never commit credentials and never modify the family's real data.
- Run on an iPhone simulator and, for Mac coverage, with XCUITest on My Mac. Keep screenshots out of Git and free of household data.
- Automation never deletes accounts, uploads builds, or changes real data outside the test household.

## Workflow

1. Build and install `Koda` on a booted simulator (Xcode MCP build, then run; or `xcodebuild` + `xcrun simctl install` for diagnostics).
2. `maestro --device <IOS_UDID> test maestro/flows/<flow>.yaml`, or run the XCUITest target from the Xcode MCP.
3. On failure, open the screenshot, inspect the hierarchy, fix the app or the selector, rerun.
4. Report device/Mac, locale, flows run, pass/fail, and screenshot paths.
