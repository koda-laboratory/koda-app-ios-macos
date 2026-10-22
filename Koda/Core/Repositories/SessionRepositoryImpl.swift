final class SessionRepositoryImpl: SessionRepository, Sendable {
    private struct StoredSession: Storable {
        static let currentIdentifier = "current-user-session"
        static let storageIdentifier = "user-session"

        let id: String
        let session: UserSession

        init(session: UserSession) {
            self.id = Self.currentIdentifier
            self.session = session
        }
    }

    // MARK: - Properties

    private let persistentDataSource: any KeychainPersistentDataSource
    private let volatileDataSource: any VolatileDataSource

    // MARK: - Lifecycle

    init(
        persistentDataSource: any KeychainPersistentDataSource,
        volatileDataSource: any VolatileDataSource
    ) {
        self.persistentDataSource = persistentDataSource
        self.volatileDataSource = volatileDataSource
    }

    // MARK: - Public methods

    func read() async throws -> UserSession? {
        if let storedSession = try await volatileDataSource.read(
            StoredSession.self,
            id: StoredSession.currentIdentifier
        ) {
            return storedSession.session
        }

        guard
            let storedSession = try await persistentDataSource.read(
                StoredSession.self,
                id: StoredSession.currentIdentifier
            )
        else {
            return nil
        }

        try await volatileDataSource.create(storedSession)
        return storedSession.session
    }

    func save(_ session: UserSession) async throws {
        let storedSession = StoredSession(session: session)
        try await persistentDataSource.update(storedSession)
        try await volatileDataSource.update(storedSession)
    }

    func delete() async throws {
        try await persistentDataSource.delete(
            StoredSession.self,
            id: StoredSession.currentIdentifier
        )
        try await volatileDataSource.delete(
            StoredSession.self,
            id: StoredSession.currentIdentifier
        )
    }
}
