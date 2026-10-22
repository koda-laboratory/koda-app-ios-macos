import Foundation

/// Public, build-time configuration exposed through `Configuration/Info.plist` (values from
/// `Configuration/Koda.xcconfig`). Koda has a single environment.
enum AppEnvironment {
    /// `group.com.kodalabs.app`, shared by the app, its widgets and intents.
    static var appGroup: String? {
        nonEmptyValue(forKey: "APP_GROUP")
    }

    /// Fully qualified keychain access group (`<TeamID>.com.kodalabs.app`).
    static var keychainAccessGroup: String? {
        nonEmptyValue(forKey: "KEYCHAIN_ACCESS_GROUP")
    }

    /// `BGAppRefreshTask` identifier used by the background sync (iOS).
    static var backgroundSyncTaskIdentifier: String? {
        nonEmptyValue(forKey: "BACKGROUND_SYNC_TASK_IDENTIFIER")
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.kodalabs.app"
    }

    static func nonEmptyValue(forKey key: String, bundle: Bundle = .main) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unresolved build setting is left as `$(NAME)` in the processed Info.plist.
        guard !trimmedValue.isEmpty, !trimmedValue.hasPrefix("$(") else { return nil }
        return trimmedValue
    }
}
