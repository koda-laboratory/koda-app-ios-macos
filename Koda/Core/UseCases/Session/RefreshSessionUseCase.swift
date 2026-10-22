/// Exchanges the stored refresh token for a new session and persists it.
///
/// Only `HTTPSessionRecovery` calls it, which guarantees a single refresh in flight: Supabase rotates the
/// refresh token on every use and revokes the session if an old one is replayed.
protocol RefreshSessionUseCase: Sendable {
    func execute() async throws(KodaError)
}

final class RefreshSessionUseCaseImpl: RefreshSessionUseCase, Sendable {
    // MARK: - Properties

    private let authRepository: any AuthRepository
    private let sessionService: any SessionService

    // MARK: - Lifecycle

    init(authRepository: any AuthRepository, sessionService: any SessionService) {
        self.authRepository = authRepository
        self.sessionService = sessionService
    }

    // MARK: - Public Methods

    func execute() async throws(KodaError) {
        guard let session = try await sessionService.current(errorHandling: .suppressed) else {
            throw KodaError(
                type: .auth,
                reason: "There is no stored session to refresh.",
                rawCode: KodaErrorCode.sessionNotFound.rawValue
            )
        }

        let refreshedSession = try await authRepository.refreshSession(refreshToken: session.refreshToken)
        try await sessionService.save(refreshedSession, errorHandling: .suppressed)
    }
}
