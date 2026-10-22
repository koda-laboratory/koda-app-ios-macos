import Foundation

@testable import Koda

/// The real HTTP stack (executor, single-flight recovery, session service, Supabase headers) over a fake transport.
struct TestHTTPStack {
    let transport: FakeHTTPTransport
    let errorCenter: KodaErrorCenter
    let sessionService: SessionServiceImpl
    let httpService: HTTPServiceImpl
    let headerProvider: SupabaseHeaderProvider
    let authRepository: AuthRepositoryImpl

    init(
        session: UserSession?,
        now: Date = .now,
        handler: @escaping FakeHTTPTransport.Handler
    ) {
        let transport = FakeHTTPTransport(handler: handler)
        let errorCenter = KodaErrorCenter()
        let sessionService = SessionServiceImpl(
            repository: InMemorySessionRepository(session: session),
            errorCenter: errorCenter,
            loggerService: SilentLoggerService(),
            clock: { now }
        )
        let refreshUseCase = LateBound<any RefreshSessionUseCase>()
        let recovery = HTTPSessionRecoveryImpl(
            refreshSessionUseCaseProvider: { refreshUseCase.value ?? UnavailableRefreshSessionUseCase() },
            errorCenter: errorCenter,
            loggerService: SilentLoggerService()
        )
        let httpService = HTTPServiceImpl(
            executor: HTTPRequestExecutorImpl(
                httpLogger: HTTPLoggerImpl(configuration: .disabled, loggerService: SilentLoggerService()),
                transport: transport
            ),
            errorCenter: errorCenter,
            sessionRecovery: recovery,
            sessionExpiry: sessionService
        )
        let headerProvider = SupabaseHeaderProvider(
            sessionProvider: sessionService,
            publishableKey: { "sb_publishable_test" }
        )
        let authRepository = AuthRepositoryImpl(
            remoteDataSource: AuthRemoteDataSourceImpl(httpService: httpService, headerProvider: headerProvider)
        )
        refreshUseCase.set(RefreshSessionUseCaseImpl(authRepository: authRepository, sessionService: sessionService))

        self.transport = transport
        self.errorCenter = errorCenter
        self.sessionService = sessionService
        self.httpService = httpService
        self.headerProvider = headerProvider
        self.authRepository = authRepository
    }

    /// GoTrue token grant response.
    static func sessionJSON(access: String, refresh: String, userID: String = TestDatabase.userID) -> Data {
        TestJSON.data([
            "access_token": access,
            "token_type": "bearer",
            "expires_in": 3600,
            "refresh_token": refresh,
            "user": ["id": userID, "email": "test@example.com"],
        ])
    }

    /// `GET /me` response.
    static func meJSON(userID: String = TestDatabase.userID, householdID: String = TestDatabase.householdID) -> Data {
        TestJSON.data([
            "user_id": userID,
            "profile": ["id": userID, "display_name": "Manu", "avatar_emoji": "🧑‍🍳"],
            "households": [
                [
                    "id": householdID, "name": "Casa", "timezone": "Europe/Madrid", "role": "owner",
                    "members": [
                        ["user_id": userID, "role": "owner", "display_name": "Manu", "avatar_emoji": "🧑‍🍳"]
                    ],
                ]
            ],
        ])
    }

    static func session(access: String = "access-1", refresh: String = "refresh-1", expiresAt: Date) -> UserSession {
        UserSession(userId: TestDatabase.userID, accessToken: access, refreshToken: refresh, expiresAt: expiresAt)
    }
}

private struct UnavailableRefreshSessionUseCase: RefreshSessionUseCase {
    func execute() async throws(KodaError) {
        throw KodaError(type: .internal, reason: "Refresh use case not wired.")
    }
}
