import Foundation

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

// MARK: - Platform

/// The platform-specific facts the rest of the app needs. `Core/Platform/` and `App/` are the only places
/// allowed to branch with `#if os(...)` (see the `multiplatform` rule).
enum PlatformInfo {
    /// Value sent to the backend (`devices.platform`): `ios` or `macos`.
    static var platformName: String {
        #if os(iOS)
            "ios"
        #elseif os(macOS)
            "macos"
        #else
            "unknown"
        #endif
    }

    static var operatingSystemVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    /// `CFBundleShortVersionString` and `CFBundleVersion`, for example `1.0.0 (1)`.
    static var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        return "\(version) (\(build))"
    }
}

// MARK: - Keyboard

@MainActor
enum PlatformKeyboard {
    /// Resigns the current first responder. The Mac has no software keyboard, so it is a no-op there.
    static func dismiss() {
        #if os(iOS)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - Remote Notifications

@MainActor
enum PlatformRemoteNotifications {
    /// Registers with APNs. Koda v1 only receives silent pushes, so no permission prompt is needed.
    static func register() {
        #if os(iOS)
            UIApplication.shared.registerForRemoteNotifications()
        #elseif os(macOS)
            NSApplication.shared.registerForRemoteNotifications()
        #endif
    }
}
