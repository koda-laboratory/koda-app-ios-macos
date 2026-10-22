import Foundation

// MARK: - Error

/// The only error type that escapes the network, storage and sync layers (Gotty's `ARPError`).
struct KodaError: Error, Sendable, Equatable, LocalizedError {
    let type: KodaErrorType
    let reason: String
    /// Machine-readable code returned by Supabase (`error_code`, `code` or `error`), when there is one.
    let rawCode: String?
    let statusCode: Int?
    let context: HTTPRequestContext?

    var code: KodaErrorCode? {
        rawCode.flatMap(KodaErrorCode.init(rawValue:))
    }

    var errorDescription: String? { reason }

    init(
        type: KodaErrorType,
        reason: String,
        rawCode: String? = nil,
        statusCode: Int? = nil,
        _ context: HTTPRequestContext? = nil
    ) {
        self.type = type
        self.reason = reason
        self.rawCode = rawCode
        self.statusCode = statusCode
        self.context = context
    }

    func attach(_ context: HTTPRequestContext) -> Self {
        Self(type: type, reason: reason, rawCode: rawCode, statusCode: statusCode, self.context ?? context)
    }
}

struct HTTPRequestContext: Sendable, Equatable {
    let method: HTTPMethod
    let path: String
}

// MARK: - Type

enum KodaErrorType: String, Sendable, Equatable {
    case apiRequestCancelled = "API_REQUEST_CANCELLED"
    case apiTimeout = "API_TIMEOUT_ERROR"
    case apiUnknown = "API_UNKNOWN_ERROR"
    case auth = "AUTH_ERROR"
    case badModelParse = "BAD_MODEL_PARSE"
    case badRequest = "BAD_REQUEST"
    case conflict = "CONFLICT"
    case forbidden = "FORBIDDEN"
    case `internal` = "INTERNAL_ERROR"
    case noInternet = "NO_INTERNET_CONNECTION"
    case notFound = "NOT_FOUND"
    case rateLimited = "RATE_LIMITED"
    case server = "SERVER_ERROR"
    case storage = "STORAGE_ERROR"
    case unsecureConnection = "UNSECURE_NETWORK_CONNECTION"

    /// Category of an unsuccessful HTTP status when the body carries no better information.
    init(statusCode: Int) {
        self =
            switch statusCode {
            case 400, 422: .badRequest
            case 401: .auth
            case 403: .forbidden
            case 404: .notFound
            case 408: .apiTimeout
            case 409: .conflict
            case 429: .rateLimited
            case 500...599: .server
            default: .apiUnknown
            }
    }
}

// MARK: - Code

/// Codes returned by Supabase Auth (GoTrue `error_code`, legacy OAuth `error`) and PostgREST.
/// The Koda `api` Edge Function contract is owned by `koda-backend`; add its codes here when it is final.
enum KodaErrorCode: String, Sendable, Equatable, CaseIterable {
    // GoTrue
    case badJWT = "bad_jwt"
    case emailNotConfirmed = "email_not_confirmed"
    case invalidCredentials = "invalid_credentials"
    case invalidGrant = "invalid_grant"
    case noAuthorization = "no_authorization"
    case overRequestRateLimit = "over_request_rate_limit"
    case refreshTokenAlreadyUsed = "refresh_token_already_used"
    case refreshTokenNotFound = "refresh_token_not_found"
    case sessionExpired = "session_expired"
    case sessionNotFound = "session_not_found"
    case signupDisabled = "signup_disabled"
    case userBanned = "user_banned"
    case userNotFound = "user_not_found"
    case validationFailed = "validation_failed"
    // PostgREST
    case postgrestJWTInvalid = "PGRST301"
    case postgrestJWTExpired = "PGRST303"
}
