/// Tells whether the stored access token is about to expire, so it is refreshed before a request instead of
/// after a 401.
protocol SessionExpiryProviding: Sendable {
    func sessionNeedsRefresh() async -> Bool
}

protocol HTTPService: Sendable {
    @discardableResult
    func execute<Request: HTTPRequest>(_ request: Request) async throws(KodaError) -> Request.Response
}

/// Executes requests with transparent session recovery and publishes only the final failure.
final class HTTPServiceImpl: HTTPService, Sendable {
    // MARK: - Properties

    private let executor: any HTTPRequestExecuting
    private let errorCenter: KodaErrorCenter
    private let sessionRecovery: any HTTPSessionRecovery
    private let sessionExpiry: (any SessionExpiryProviding)?

    // MARK: - Lifecycle

    init(
        executor: any HTTPRequestExecuting,
        errorCenter: KodaErrorCenter,
        sessionRecovery: any HTTPSessionRecovery,
        sessionExpiry: (any SessionExpiryProviding)? = nil
    ) {
        self.executor = executor
        self.errorCenter = errorCenter
        self.sessionRecovery = sessionRecovery
        self.sessionExpiry = sessionExpiry
    }

    // MARK: - Public Methods

    @discardableResult
    func execute<Request: HTTPRequest>(_ request: Request) async throws(KodaError) -> Request.Response {
        var recoveryGeneration: Int?
        if request.allowsSessionRecovery {
            recoveryGeneration = await sessionRecovery.generation()
            if let generation = recoveryGeneration, try await refreshIfAboutToExpire(after: generation) {
                recoveryGeneration = await sessionRecovery.generation()
            }
        }

        do {
            return try await executor.execute(request)
        } catch let error {
            guard let recoveryGeneration, error.action == .reauthenticate else {
                await errorCenter.publish(error, policy: request.errorHandling)
                throw error
            }

            return try await recoverSessionAndRetry(
                request,
                triggeringError: error,
                recoveryGeneration: recoveryGeneration
            )
        }
    }

    // MARK: - Session Recovery

    /// Proactive refresh when the access token expires within 60 s, through the same single-flight recovery as a
    /// 401. Offline or server failures let the request go ahead (it may still succeed or recover on 401);
    /// rejected credentials stop it (the recovery already published `forceLogin`).
    private func refreshIfAboutToExpire(after generation: Int) async throws(KodaError) -> Bool {
        guard let sessionExpiry, await sessionExpiry.sessionNeedsRefresh() else { return false }

        let trigger = KodaError(
            type: .auth,
            reason: "The access token is about to expire.",
            rawCode: KodaErrorCode.sessionExpired.rawValue
        )
        switch await sessionRecovery.recoverSession(after: generation, triggeredBy: trigger) {
        case .recovered:
            return true
        case .failed(let error) where error.invalidatesSession:
            throw error
        case .failed:
            return false
        }
    }

    private func recoverSessionAndRetry<Request: HTTPRequest>(
        _ request: Request,
        triggeringError: KodaError,
        recoveryGeneration: Int
    ) async throws(KodaError) -> Request.Response {
        let recoveryResult = await sessionRecovery.recoverSession(
            after: recoveryGeneration,
            triggeredBy: triggeringError
        )

        switch recoveryResult {
        case .recovered:
            return try await retry(request)
        case let .failed(recoveryError):
            throw recoveryError
        }
    }

    private func retry<Request: HTTPRequest>(_ request: Request) async throws(KodaError) -> Request.Response {
        do {
            // Rebuild the URLRequest so its header provider reads the newly persisted token.
            return try await executor.execute(request)
        } catch let error {
            if error.action == .reauthenticate {
                await errorCenter.publish(error, action: .forceLogin)
            } else {
                await errorCenter.publish(error, policy: request.errorHandling)
            }
            throw error
        }
    }
}
