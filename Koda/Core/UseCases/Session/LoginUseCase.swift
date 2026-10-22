/// Signs in with email and password (GoTrue password grant), stores the session in the Keychain and caches
/// `GET /me`. Signing in as a different user than the cached one wipes the previous user's local data first.
protocol LoginUseCase: Sendable {
    @discardableResult
    func execute(email: String, password: String) async throws(KodaError) -> HouseholdContext
}

final class LoginUseCaseImpl: LoginUseCase, Sendable {
    // MARK: - Properties

    private let authRepository: any AuthRepository
    private let sessionService: any SessionService
    private let meRepository: any MeRepository
    private let localDataRepository: any LocalDataRepository

    // MARK: - Lifecycle

    init(
        authRepository: any AuthRepository,
        sessionService: any SessionService,
        meRepository: any MeRepository,
        localDataRepository: any LocalDataRepository
    ) {
        self.authRepository = authRepository
        self.sessionService = sessionService
        self.meRepository = meRepository
        self.localDataRepository = localDataRepository
    }

    // MARK: - Public Methods

    @discardableResult
    func execute(email: String, password: String) async throws(KodaError) -> HouseholdContext {
        let session = try await authRepository.signIn(email: email, password: password)
        try await sessionService.save(session, errorHandling: .local)

        do {
            // A forced re-login of the same user keeps the database and the outbox (local-first rule).
            if let previous = try await meRepository.cached(),
                previous.userID.uuidString.lowercased() != session.userId.lowercased()
            {
                try await localDataRepository.eraseAll()
            }
            return try await meRepository.refresh()
        } catch {
            try? await sessionService.delete()
            throw error
        }
    }
}
