import Foundation
import LocalAuthentication

/// Device-owner authentication (Face ID / Touch ID with passcode or Mac password fallback).
protocol BiometricAuthenticating: Sendable {
    /// `false` when the device has no biometrics and no passcode, so locking would leave the user stuck.
    func canAuthenticate() -> Bool
    func authenticate(reason: String) async throws -> Bool
}

/// `LAContext` with `.deviceOwnerAuthentication`, identical on iPhone and Mac.
struct LocalAuthenticationAuthenticator: BiometricAuthenticating {
    func canAuthenticate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate(reason: String) async throws -> Bool {
        try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
}
