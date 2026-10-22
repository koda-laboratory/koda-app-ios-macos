import Foundation
import LocalAuthentication

/// Biometric authentication only (Face ID / Touch ID / Optic ID). The device passcode is never offered: the
/// fallback is Koda's own password login, shown on the same screen.
protocol BiometricAuthenticating: Sendable {
    /// `false` when the device has no enrolled biometrics; the app then opens directly (the device itself is
    /// already protected by its passcode).
    func canAuthenticate() -> Bool
    /// The kind of biometrics the device offers, to label the unlock button.
    func biometry() -> BiometryKind
    /// `false` when the person cancels or chooses the password fallback.
    func authenticate(reason: String) async throws -> Bool
}

extension BiometricAuthenticating {
    func biometry() -> BiometryKind {
        canAuthenticate() ? .faceID : .none
    }
}

/// `LAContext` with `.deviceOwnerAuthenticationWithBiometrics`, identical on iPhone and Mac.
struct LocalAuthenticationAuthenticator: BiometricAuthenticating {
    func canAuthenticate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func biometry() -> BiometryKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return .none }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "lock.use-password")
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch let error as LAError where Self.isDismissal(error.code) {
            return false
        }
    }

    private static func isDismissal(_ code: LAError.Code) -> Bool {
        switch code {
        case .userCancel, .userFallback, .systemCancel, .appCancel: true
        default: false
        }
    }
}
