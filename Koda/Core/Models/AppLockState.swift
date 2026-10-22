import Foundation

enum AppLockState: Sendable, Equatable {
    case unlocked
    case locked
}

/// Biometric lock preferences, configurable from Profile.
struct BiometricLockPolicy: Codable, Sendable, Equatable {
    var isEnabled: Bool
    /// Time in background after which returning to the app locks it again.
    var backgroundTimeout: TimeInterval

    static let `default` = BiometricLockPolicy(isEnabled: true, backgroundTimeout: 5 * 60)
}
