# Build and simulator state recovery

Use only when evidence points to stale state; never clean caches routinely.

| Symptom | Recovery |
| --- | --- |
| Flow exercises an old build | Rebuild `Koda` and reinstall (`xcrun simctl install <IOS_UDID> <path to Koda.app>`), then relaunch |
| Simulator not booted or unresponsive | `xcrun simctl boot <IOS_UDID>`; `xcrun simctl shutdown all` then boot again |
| Stored session leaks between flows | `xcrun simctl uninstall <IOS_UDID> com.kodalabs.app` (the Keychain survives uninstall; use `xcrun simctl erase <IOS_UDID>` for a clean device) |
| Stale local database | The GRDB file lives in the App Group container; uninstall the app (iPhone) or remove the app's group container (Mac) only with the user's consent |
| Mac app keeps old state | Quit the app; its sandbox container is under `~/Library/Containers/com.kodalabs.app` and the shared one under `~/Library/Group Containers/` |
| Package resolution errors | Xcode: File → Packages → Reset Package Caches; keep the committed `Package.resolved` |
| Stale DerivedData after large refactors | Delete the project's DerivedData folder (or `.build/DerivedData` for fastlane builds) once the build log proves stale state |

If a clean build reproduces the error, treat it as a real failure and record Xcode, Swift, and package versions with the command and log.
