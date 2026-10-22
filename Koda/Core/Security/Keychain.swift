import Foundation
import Security

// MARK: - Keychain

/// Thin wrapper over the Security framework storing UTF-8 strings as generic password items.
///
/// Items are scoped by `kSecAttrService` and stored in the shared keychain access group so the app, its
/// widgets and intents read the same session. `kSecUseDataProtectionKeychain` is always set: on macOS it
/// selects the iOS-style data protection keychain (required for access groups in a sandboxed app), on iOS
/// it is already the only keychain.
struct Keychain: Sendable {
    /// The shared Koda keychain.
    static let shared = Keychain(
        service: AppEnvironment.bundleIdentifier,
        accessGroup: AppEnvironment.keychainAccessGroup
    )

    let service: String
    let accessGroup: String?

    private let lock = NSLock()

    init(service: String, accessGroup: String?) {
        self.service = service
        self.accessGroup = accessGroup
    }

    /// Retrieves the string stored for the given key.
    func string(forKey key: String) throws -> String? {
        guard let data = try data(forKey: key) else {
            return nil
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError(invalidValue: true)
        }
        return string
    }

    /// Stores a key value pair, replacing any existing value.
    func set(_ string: String, forKey key: String, access: KeychainAccess = .firstUnlock) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError(invalidValue: true)
        }
        try set(data, forKey: key, access: access)
    }

    /// Deletes the value stored for the given key.
    func removeValue(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        try removeHoldingLock(forKey: key)
    }

    /// Removes every item of this service.
    func removeAll() throws {
        lock.lock()
        defer { lock.unlock() }

        let code = performWithAccessGroupFallback { query in SecItemDelete(query as CFDictionary) }
        guard code == errSecSuccess || code == errSecItemNotFound else {
            throw KeychainError(code: code)
        }
    }

    // MARK: - Private methods

    private func baseQuery(includingAccessGroup: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
        ]
        if includingAccessGroup, let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    /// Runs a keychain call with the shared access group. Unsigned local builds (CI, `CODE_SIGNING_ALLOWED=NO`)
    /// lack the entitlement, so they fall back to the app's default group instead of failing.
    private func performWithAccessGroupFallback(
        _ extraAttributes: [String: Any] = [:],
        _ operation: ([String: Any]) -> OSStatus
    ) -> OSStatus {
        let query = baseQuery(includingAccessGroup: true).merging(extraAttributes) { _, new in new }
        let code = operation(query)
        guard code == errSecMissingEntitlement, accessGroup != nil else { return code }

        let fallbackQuery = baseQuery(includingAccessGroup: false).merging(extraAttributes) { _, new in new }
        return operation(fallbackQuery)
    }

    private func data(forKey key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }

        var result: AnyObject?
        let code = performWithAccessGroupFallback(
            [
                kSecAttrAccount as String: key,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecReturnData as String: true,
            ]
        ) { query in
            SecItemCopyMatching(query as CFDictionary, &result)
        }
        guard code == errSecSuccess || code == errSecItemNotFound else {
            throw KeychainError(code: code)
        }
        return result as? Data
    }

    private func set(_ data: Data, forKey key: String, access: KeychainAccess) throws {
        lock.lock()
        defer { lock.unlock() }

        try removeHoldingLock(forKey: key)
        let code = performWithAccessGroupFallback(
            [
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: access.value,
            ]
        ) { query in
            SecItemAdd(query as CFDictionary, nil)
        }
        guard code == errSecSuccess else {
            throw KeychainError(code: code)
        }
    }

    private func removeHoldingLock(forKey key: String) throws {
        let code = performWithAccessGroupFallback([kSecAttrAccount as String: key]) { query in
            SecItemDelete(query as CFDictionary)
        }
        guard code == errSecSuccess || code == errSecItemNotFound else {
            throw KeychainError(code: code)
        }
    }
}

// MARK: - Access

/// When a stored item can be read.
enum KeychainAccess {
    /// Accessible when the device is unlocked.
    case unlocked
    /// Accessible only when the device is unlocked, and does not transfer to new devices.
    case unlockedThisDeviceOnly
    /// Accessible after the first unlock until restart. Required by background sync, silent pushes and
    /// intents, which run while the iPhone is locked.
    case firstUnlock
    /// Accessible after the first unlock until restart, and does not transfer to new devices.
    case firstUnlockThisDeviceOnly

    var value: String {
        switch self {
        case .unlocked:
            kSecAttrAccessibleWhenUnlocked as String
        case .unlockedThisDeviceOnly:
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        case .firstUnlock:
            kSecAttrAccessibleAfterFirstUnlock as String
        case .firstUnlockThisDeviceOnly:
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
        }
    }
}

// MARK: - Error

/// Thrown on keychain failures.
struct KeychainError: Error, CustomStringConvertible {
    let message: String

    init(invalidValue: Bool = false) {
        self.message = invalidValue ? "Invalid value" : "Unknown error"
    }

    init(code: OSStatus) {
        self.message = SecCopyErrorMessageString(code, nil) as String? ?? "Unknown error (\(code))"
    }

    var description: String { message }
}
