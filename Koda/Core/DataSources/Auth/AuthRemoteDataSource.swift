protocol AuthRemoteDataSource: Sendable {
    func signIn(email: String, password: String) async throws(KodaError) -> AuthSessionResponseDTO
    func refreshSession(refreshToken: String) async throws(KodaError) -> AuthSessionResponseDTO
    func signOut() async throws(KodaError)
}

/// Supabase Auth (GoTrue) through the shared `HTTPService`.
final class AuthRemoteDataSourceImpl: AuthRemoteDataSource, Sendable {
    // MARK: - Properties

    private let httpService: any HTTPService
    private let headerProvider: any HTTPHeaderProvider

    // MARK: - Lifecycle

    init(httpService: any HTTPService, headerProvider: any HTTPHeaderProvider) {
        self.httpService = httpService
        self.headerProvider = headerProvider
    }

    // MARK: - Public Methods

    func signIn(email: String, password: String) async throws(KodaError) -> AuthSessionResponseDTO {
        try await httpService.execute(AuthAPI.signIn(email: email, password: password, headerProvider: headerProvider))
    }

    func refreshSession(refreshToken: String) async throws(KodaError) -> AuthSessionResponseDTO {
        try await httpService.execute(
            AuthAPI.refreshSession(refreshToken: refreshToken, headerProvider: headerProvider)
        )
    }

    func signOut() async throws(KodaError) {
        try await httpService.execute(AuthAPI.signOut(headerProvider: headerProvider))
    }
}
