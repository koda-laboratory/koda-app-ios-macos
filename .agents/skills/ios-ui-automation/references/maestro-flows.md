# Maestro flows (iPhone simulator)

## Minimal flow

Illustrative: the identifiers must exist on the screens before the flow can run.

```yaml
# maestro/flows/shopping-offline.yaml
appId: com.kodalabs.app
tags: [smoke]
---
- runFlow: ../subflows/launch-clean.yaml
- tapOn:
    id: "tab.shopping"
- tapOn:
    id: "shopping.quick-add"
- inputText: "leche"
- pressKey: Enter
- assertVisible: "leche"
- takeScreenshot: screenshots/shopping-added
```

To exercise offline behavior, disable the Mac's network (the simulator shares it) or use Network Link Conditioner, then assert the pending-changes indicator.

## Clean launch subflow

```yaml
# maestro/subflows/launch-clean.yaml
appId: com.kodalabs.app
---
- launchApp:
    clearState: true
```

`clearState` does not clear the Keychain on iOS; use `xcrun simctl erase` when a flow needs no stored session.

## Conventions

- One user goal per flow; share setup through subflows.
- Prefer `assertVisible` on ids over sleeps; use `extendedWaitUntil` only for sync-dependent content.
- Name screenshots `<flow>-<state>-<locale>-<device>`.
- Tag flows `smoke` (fast) or `full`.

## Running

```bash
xcrun simctl list devices booted
maestro --device <IOS_UDID> test maestro/flows/shopping-offline.yaml
maestro test maestro/ --include-tags smoke --format junit --output .build/maestro/report.xml
```
