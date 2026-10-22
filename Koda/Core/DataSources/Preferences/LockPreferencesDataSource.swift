import Foundation

/// Persists the biometric lock policy (a per-device preference, not synced).
protocol LockPreferencesDataSource: Sendable {
    func policy() -> BiometricLockPolicy
    func save(_ policy: BiometricLockPolicy)
}

final class UserDefaultsLockPreferencesDataSource: LockPreferencesDataSource, Sendable {
    private static let key = "com.kodalabs.app.biometric-lock-policy"

    // `UserDefaults` is thread-safe; it is only not annotated as `Sendable`.
    private nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func policy() -> BiometricLockPolicy {
        guard let data = defaults.data(forKey: Self.key),
            let policy = try? JSONDecoder().decode(BiometricLockPolicy.self, from: data)
        else {
            return .default
        }
        return policy
    }

    func save(_ policy: BiometricLockPolicy) {
        guard let data = try? JSONEncoder().encode(policy) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
