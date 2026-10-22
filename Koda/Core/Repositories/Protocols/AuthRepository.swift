protocol AuthRepository: Sendable {
    func signIn(email: String, password: String) async throws(KodaError) -> UserSession
    func refreshSession(refreshToken: String) async throws(KodaError) -> UserSession
    func signOut() async throws(KodaError)
}
