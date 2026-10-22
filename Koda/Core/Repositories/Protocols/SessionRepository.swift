protocol SessionRepository: Sendable {
    func delete() async throws
    func read() async throws -> UserSession?
    func save(_ session: UserSession) async throws
}
