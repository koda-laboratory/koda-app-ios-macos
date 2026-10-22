enum SessionRecoveryResult: Sendable, Equatable {
    case failed(KodaError)
    case recovered
}

// MARK: - Protocol HTTPSessionRecovery

protocol HTTPSessionRecovery: Sendable {
    func generation() async -> Int
    func recoverSession(
        after generation: Int,
        triggeredBy error: KodaError
    ) async -> SessionRecoveryResult
}

// MARK: - Implementation

/// Single-flight session refresh.
///
/// Supabase rotates the refresh token on every use and revokes the session when an already used token is
/// replayed outside a short window, so concurrent 401s must share ONE refresh. Callers pass the generation they
/// observed before sending their request: if another refresh finished in the meantime they get its result
/// without refreshing again.
actor HTTPSessionRecoveryImpl: HTTPSessionRecovery {
    // MARK: - Properties

    // Resolves the use case lazily to avoid the HTTPService → recovery → AuthRepository → HTTPService DI cycle.
    private let refreshSessionUseCaseProvider: @Sendable () -> any RefreshSessionUseCase
    private let errorCenter: KodaErrorCenter
    private let loggerService: any LoggerService

    private var currentGeneration = 0
    private var latestResult = SessionRecoveryResult.recovered
    private var recoveryTask: Task<SessionRecoveryResult, Never>?

    // MARK: - Lifecycle

    init(
        refreshSessionUseCaseProvider: @escaping @Sendable () -> any RefreshSessionUseCase,
        errorCenter: KodaErrorCenter,
        loggerService: any LoggerService
    ) {
        self.refreshSessionUseCaseProvider = refreshSessionUseCaseProvider
        self.errorCenter = errorCenter
        self.loggerService = loggerService
    }

    // MARK: - Public Methods

    func generation() -> Int {
        currentGeneration
    }

    func recoverSession(
        after generation: Int,
        triggeredBy error: KodaError
    ) async -> SessionRecoveryResult {
        // Another request may already have renewed the session after this request was sent.
        guard generation >= currentGeneration else { return latestResult }

        if let recoveryTask {
            return await recoveryTask.value
        }

        let refreshSession = refreshSessionUseCaseProvider()
        let errors = errorCenter
        let logger = loggerService
        let task: Task<SessionRecoveryResult, Never> = Task { [refreshSession, errors, logger] in
            logger.warning(
                "🔐 [AUTH][SESSION] Access token rejected; refreshing the session.",
                attributes: ["error.code": error.rawCode ?? "none"]
            )

            do {
                try await refreshSession.execute()
                logger.info("✅ [AUTH][SESSION] Session refreshed.")
                return .recovered
            } catch {
                let recoveryError = KodaErrorMapper.map(error)
                logger.error(
                    "❌ [AUTH][SESSION] Session refresh failed.",
                    attributes: [
                        "error.code": recoveryError.rawCode ?? "none",
                        "error.reason": recoveryError.reason,
                        "error.type": recoveryError.type.rawValue,
                    ]
                )
                // Offline or server failures keep the session (local-first); only invalid credentials log out.
                if recoveryError.invalidatesSession {
                    await errors.publish(recoveryError, action: .forceLogin)
                }
                return .failed(recoveryError)
            }
        }

        recoveryTask = task
        let result = await task.value
        recoveryTask = nil
        latestResult = result
        currentGeneration += 1

        return result
    }
}
