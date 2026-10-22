struct KodaErrorHandlingPolicy: Sendable {
    // MARK: - Strategy

    private enum Strategy: Sendable {
        case automatic
        case local
        case suppressed
    }

    // MARK: - Presets

    /// Publish both generic presentations and app-wide actions.
    static let automatic = KodaErrorHandlingPolicy(strategy: .automatic)

    /// The initiating flow owns presentation; app-wide session actions are still published.
    static let local = KodaErrorHandlingPolicy(strategy: .local)

    /// Publish nothing globally. The typed error is still thrown to the caller.
    static let suppressed = KodaErrorHandlingPolicy(strategy: .suppressed)

    // MARK: - Properties

    private let exclude: [KodaErrorCode]
    private let strategy: Strategy

    // MARK: - Lifecycle

    private init(strategy: Strategy, exclude: [KodaErrorCode] = []) {
        self.exclude = exclude
        self.strategy = strategy
    }

    // MARK: - Public Methods

    /// Publishes automatically except for errors explicitly owned by the initiating flow.
    static func automatic(exclude: [KodaErrorCode]) -> KodaErrorHandlingPolicy {
        KodaErrorHandlingPolicy(strategy: .automatic, exclude: exclude)
    }

    // MARK: - Internal Methods

    func shouldPublish(error: KodaError) -> Bool {
        if let code = error.code, exclude.contains(code) {
            return false
        }

        return switch strategy {
        case .automatic:
            error.action != .ignore
        case .local:
            error.action.isAppWide
        case .suppressed:
            false
        }
    }
}

/// Semantic work the app coordinator should perform after a finalized failure.
enum KodaErrorAction: Sendable, Equatable {
    /// Show the login again. Local data (GRDB and the outbox) is kept so pending changes sync after re-login.
    case forceLogin
    /// Do not show or perform anything globally.
    case ignore
    /// Present the generic error UI resolved from the error code/type.
    case present
    /// Refresh the session once (single-flight) and retry the request.
    case reauthenticate

    var isAppWide: Bool {
        switch self {
        case .forceLogin, .reauthenticate:
            true
        case .ignore, .present:
            false
        }
    }
}

extension KodaError {
    var action: KodaErrorAction {
        switch code {
        case .invalidGrant, .refreshTokenAlreadyUsed, .refreshTokenNotFound, .sessionNotFound, .userBanned,
            .userNotFound:
            return .forceLogin
        case .badJWT, .noAuthorization, .sessionExpired, .postgrestJWTExpired, .postgrestJWTInvalid:
            return .reauthenticate
        default:
            if type == .apiRequestCancelled {
                return .ignore
            }
            // Any other 401 means the access token was rejected: refresh it once.
            return statusCode == 401 ? .reauthenticate : .present
        }
    }

    /// `true` when a failed session refresh means the stored credentials are no longer usable, as opposed
    /// to a transient failure (no network, timeout, server error) that must keep the user signed in.
    var invalidatesSession: Bool {
        action == .forceLogin || action == .reauthenticate || type == .auth
    }
}
