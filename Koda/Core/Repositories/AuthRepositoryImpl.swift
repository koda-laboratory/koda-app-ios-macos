final class AuthRepositoryImpl: AuthRepository, Sendable {
    // MARK: - Properties

    private let remoteDataSource: any AuthRemoteDataSource

    // MARK: - Lifecycle

    init(remoteDataSource: any AuthRemoteDataSource) {
        self.remoteDataSource = remoteDataSource
    }

    // MARK: - Public Methods

    func signIn(email: String, password: String) async throws(KodaError) -> UserSession {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let response = try await remoteDataSource.signIn(email: normalizedEmail, password: password)
        return UserSession(fromDTO: response)
    }

    func refreshSession(refreshToken: String) async throws(KodaError) -> UserSession {
        let response = try await remoteDataSource.refreshSession(refreshToken: refreshToken)
        return UserSession(fromDTO: response)
    }

    func signOut() async throws(KodaError) {
        try await remoteDataSource.signOut()
    }
}
