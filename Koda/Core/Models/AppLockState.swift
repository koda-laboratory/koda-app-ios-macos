import Foundation

enum AppLockState: Sendable, Equatable {
    case unlocked
    case locked
}

/// Biometrics available to unlock Koda; `none` means the app opens without a biometric step.
enum BiometryKind: Sendable, Equatable {
    case none
    case faceID
    case touchID
    case opticID
}

/// Biometric lock preferences, configurable from Profile.
struct BiometricLockPolicy: Codable, Sendable, Equatable {
    var isEnabled: Bool
    /// Time in background after which returning to the app locks it again.
    var backgroundTimeout: TimeInterval

    static let `default` = BiometricLockPolicy(isEnabled: true, backgroundTimeout: 5 * 60)
}
