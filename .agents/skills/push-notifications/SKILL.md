---
name: push-notifications
description: Implement Koda push on iPhone and Mac — APNs registration after login, device token upload (PUT /devices), silent background pushes that trigger SyncEngine pull/push, BGAppRefreshTask backup on iOS, widget reloads, entitlements and Info.plist background modes, and the future path for visible notifications. Use when touching remote-notification delegates, background sync, or device registration.
---

# Push notifications

> Status: app side implemented in Phase 2 (registration through `AppLifecycleCoordinator` → `RegisterDeviceUseCase` → `DeviceRepository`, silent push and `BGAppRefreshTask` → `SyncScheduler.syncNow`); the end-to-end acceptance test is Phase 4 of `../PLAN.md`. The backend side (`devices`, `push_queue`, Edge Function `push` with an ES256 `.p8` JWT over HTTP/2) lives in `../koda-backend`. The `.p8` key never enters this repository.

## v1 scope: silent sync only

Any change from another device or from the MCP server sends an invisible push → the app pulls. Nothing is displayed, so **no notification permission prompt** in v1; registering with APNs is enough.

## Registration

1. After login (and on every launch with a session), call `registerForRemoteNotifications()` through a `Core/Platform/` abstraction (`UIApplication` on iOS, `NSApplication` on macOS).
2. The delegates in `Koda/App/iOS/AppDelegate+iOS.swift` and `Koda/App/macOS/AppDelegate+macOS.swift` receive the token and forward it to `AppLifecycleCoordinator.didRegisterForRemoteNotifications(deviceToken:)`, which runs `RegisterDeviceUseCase` (`Core/UseCases/Device/`). `apns_env` comes from the `APNS_ENVIRONMENT` build setting (Info.plist).
3. Upload with `PUT /functions/v1/api/devices`: hex token, `platform` (`ios` | `macos`), `apns_env` (`sandbox` for Xcode/Debug builds, `production` for TestFlight), app version. Re-upload when the token changes.
4. Logout: `DELETE /devices/:id` before clearing the session.

## Silent push → sync

Payload sent by the backend:

```json
{ "aps": { "content-available": 1 }, "koda": { "reason": "shopping|planning|...", "cursor": 123 } }
```

Headers: `apns-push-type: background`, `apns-priority: 5`, `apns-expiration` ≈ 1 h, topic = bundle id `com.kodalabs.app` (same on iOS and macOS).

- **iOS**: `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` → `SyncEngine` pull (and push if the outbox is not empty) → call the completion handler with `.newData`/`.noData`/`.failed` within ~30 s.
- **macOS**: `application(_:didReceiveRemoteNotification:)` on the `NSApplicationDelegate` triggers the same sync while the app runs; a closed app syncs on next activation.
- After a pull with changes: `WidgetCenter.shared.reloadAllTimelines()` and reindex App Intents entities.
- The database's `completeUntilFirstUserAuthentication` protection allows writing while the iPhone is locked.

## Backups for delayed pushes

- iOS `BGAppRefreshTask` with identifier `com.kodalabs.app.refresh` (listed in `BGTaskSchedulerPermittedIdentifiers`), rescheduled after each sync.
- Sync on foreground and on network recovery (see `local-first-sync`).
- iOS throttles background pushes (a few per hour, Low Power Mode). **If the user force-quits the app from the app switcher, iOS stops delivering silent pushes until it is reopened**; Profile explains this.

## Configuration

- Entitlements: `aps-environment` in `Configuration/Koda-iOS.entitlements`, `com.apple.developer.aps-environment` in `Configuration/Koda-macOS.entitlements` (`development` locally; export rewrites to `production`).
- `Info.plist`: `UIBackgroundModes` = `remote-notification`, `fetch`; `BGTaskSchedulerPermittedIdentifiers` = `com.kodalabs.app.refresh`.
- App ID capabilities: Push Notifications (iOS + macOS).

## Acceptance test

iPhone A in background and locked → change from iPhone B → airplane mode on A → open A → the change is there. Also: tick an item on one iPhone → it appears ticked on the other and on the Mac within seconds.

## Future: visible notifications

Not in v1. When added: a dedicated permission screen (never prompt at launch), `UNUserNotificationCenterDelegate` + a `NotificationRouter` that maps responses to `AppRouter` destinations, categories with actions (for example "Sí, lo comimos" running the same use case as `LogMealIntent`), `thread-id` grouping, and per-type preferences in Profile.
