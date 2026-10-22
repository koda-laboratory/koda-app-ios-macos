---
description: Keep Koda one native SwiftUI codebase for iPhone and Mac, isolating platform code in App/ and Core/Platform/
alwaysApply: true
---

# Multiplatform (iPhone + Mac)

Koda ships one multiplatform target `Koda` (Supported Destinations: iPhone and Mac) plus the multiplatform `KodaWidgets` extension. macOS is native SwiftUI on AppKit — not Mac Catalyst and not "Designed for iPad". Both platforms share the bundle id `com.kodalabs.app` and one App Store Connect record. iPad is not a supported destination.

## Where platform code may live

- `#if os(iOS)` / `#if os(macOS)` and `import UIKit` / `import AppKit` are allowed **only** in `Koda/App/` (entry point and `App/iOS/AppDelegate+iOS.swift`, `App/macOS/AppDelegate+macOS.swift`) and `Koda/Core/Platform/`.
- `Core/Platform/` exposes small platform-neutral abstractions (for example remote-notification registration, keyboard dismissal, haptics, device/platform info, opening URLs, background refresh scheduling) that features and Core consume through protocols or plain functions.
- Features, `Common/`, domain, and data code import only SwiftUI/Foundation and cross-platform frameworks. If a feature needs a platform difference, add a tiny modifier or helper to `Core/Platform/` (or a `Common/Presentation` modifier backed by it) instead of an inline `#if os`.
- `KodaWidgets/` follows the same rule: shared widget views, platform tweaks only through availability-safe SwiftUI APIs.

## Shared UI, adapted per platform

- One view tree per screen. Platform adaptation happens through SwiftUI itself (`TabView` + `.sidebarAdaptable`, `NavigationSplitView` columns on wide layouts, toolbars, `Settings` scene, `.commands`) and small modifiers, not duplicated screens.
- iPhone: tab bar Today · Planning · Shopping · Recipes; Profile from the avatar; haptics with `sensoryFeedback`.
- Mac: same sections in the sidebar, Profile in `Settings` (⌘,), menu commands (⌘N new recipe, ⌘⇧L shopping list), hover states, higher density, resizable windows (see `app-resizability`).
- Keep hit targets, Dynamic Type, VoiceOver, Reduce Motion, and Reduce Transparency correct on both.

## Platform services

| Topic | iOS | macOS |
| --- | --- | --- |
| Delegate | `UIApplicationDelegateAdaptor` | `NSApplicationDelegateAdaptor` |
| Background sync | `BGAppRefreshTask` + silent push | silent push + sync on activation |
| Biometrics | Face ID (`LAContext`) | Touch ID / Mac password (same `LAContext`) |
| Keychain | default keychain, shared access group | `kSecUseDataProtectionKeychain = true`, shared access group |
| Entitlements | `Configuration/Koda-iOS.entitlements` | `Configuration/Koda-macOS.entitlements` (App Sandbox, `network.client`) |

Entitlements are selected per SDK with `CODE_SIGN_ENTITLEMENTS[sdk=iphone*]` / `[sdk=macosx*]`. The push entitlement key differs (`aps-environment` on iOS, `com.apple.developer.aps-environment` on macOS).

## Validation

Every feature compiles, previews, and runs on both an iPhone simulator and My Mac before it is complete (see [`development`](development.md)). Previews include an iPhone and a Mac variant (see [`swiftui-structure`](swiftui-structure.md)).
