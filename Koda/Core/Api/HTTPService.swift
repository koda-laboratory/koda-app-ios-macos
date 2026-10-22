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

    // MARK: - Lifecycle

    init(
        executor: any HTTPRequestExecuting,
        errorCenter: KodaErrorCenter,
        sessionRecovery: any HTTPSessionRecovery
    ) {
        self.executor = executor
        self.errorCenter = errorCenter
        self.sessionRecovery = sessionRecovery
    }

    // MARK: - Public Methods

    @discardableResult
    func execute<Request: HTTPRequest>(_ request: Request) async throws(KodaError) -> Request.Response {
        let recoveryGeneration: Int?
        if request.allowsSessionRecovery {
            recoveryGeneration = await sessionRecovery.generation()
        } else {
            recoveryGeneration = nil
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
