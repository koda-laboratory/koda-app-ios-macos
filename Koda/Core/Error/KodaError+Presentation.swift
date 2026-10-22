import Foundation

// MARK: - Error Presentation

struct KodaErrorPresentation: Sendable, Equatable {
    // MARK: - Properties

    let title: String
    let message: String

    // MARK: - Lifecycle

    init(error: KodaError) {
        self.title = "error.title".localized
        self.message = error.localizedPresentationKey.localized
    }
}

// MARK: - Koda Error

extension KodaError {
    /// String-catalog key of the user-facing message. Codes win over the generic type.
    var localizedPresentationKey: String {
        if let key = code?.localizedPresentationKey {
            return key
        }

        return switch type {
        case .internal: "error.type.internal"
        case .badRequest: "error.type.bad-request"
        case .auth: "error.type.authentication"
        case .forbidden: "error.type.forbidden"
        case .notFound: "error.type.not-found"
        case .conflict: "error.type.conflict"
        case .rateLimited: "error.type.rate-limit"
        case .server: "error.type.server"
        case .storage: "error.type.storage"
        case .apiTimeout: "error.type.timeout"
        case .apiRequestCancelled: "error.type.cancelled"
        case .apiUnknown: "error.type.unknown"
        case .noInternet: "error.type.no-internet"
        case .unsecureConnection: "error.type.unsecure-network"
        case .badModelParse: "error.type.bad-response"
        }
    }
}

// MARK: - Koda Error Code

private extension KodaErrorCode {
    var localizedPresentationKey: String? {
        switch self {
        case .invalidCredentials:
            "error.code.invalid-credentials"
        case .emailNotConfirmed:
            "error.code.email-not-confirmed"
        case .userBanned, .userNotFound:
            "error.code.user-unavailable"
        case .overRequestRateLimit:
            "error.type.rate-limit"
        case .invalidGrant, .refreshTokenAlreadyUsed, .refreshTokenNotFound, .sessionExpired, .sessionNotFound,
            .badJWT, .noAuthorization, .postgrestJWTExpired, .postgrestJWTInvalid:
            "error.code.expired-session"
        case .signupDisabled, .validationFailed:
            nil
        }
    }
}
