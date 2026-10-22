#if DEBUG
    import Foundation
    import Testing

    @testable import Koda

    /// Optional smoke test against the live `koda` project. Skipped unless `KODA_TEST_EMAIL` and
    /// `KODA_TEST_PASSWORD` are set for the test process (with xcodebuild, export them prefixed with
    /// `TEST_RUNNER_`). It signs in, caches `/me`, pulls everything into an in-memory database and signs out.
    @Suite("Live backend smoke test")
    struct LiveBackendSmokeTests {
        private static var credentials: (email: String, password: String)? {
            let environment = ProcessInfo.processInfo.environment
            guard let email = environment["KODA_TEST_EMAIL"], !email.isEmpty,
                let password = environment["KODA_TEST_PASSWORD"], !password.isEmpty
            else {
                return nil
            }
            return (email, password)
        }

        @Test(
            "Login, /me and a full pull return recipes",
            .enabled(if: credentials != nil, "Set KODA_TEST_EMAIL and KODA_TEST_PASSWORD to run")
        )
        func loginAndPull() async throws {
            let credentials = try #require(Self.credentials)
            let logger = SilentLoggerService()
            let errorCenter = KodaErrorCenter()
            let sessionService = SessionServiceImpl(
                repository: InMemorySessionRepository(),
                errorCenter: errorCenter,
                loggerService: logger
            )
            let refreshUseCase = LateBound<any RefreshSessionUseCase>()
            let httpService = HTTPServiceImpl(
                executor: HTTPRequestExecutorImpl(
                    httpLogger: HTTPLoggerImpl(configuration: .disabled, loggerService: logger),
                    transport: URLSessionHTTPTransport()
                ),
                errorCenter: errorCenter,
                sessionRecovery: HTTPSessionRecoveryImpl(
                    refreshSessionUseCaseProvider: { refreshUseCase.value ?? RefreshSessionUseCaseImplStub() },
                    errorCenter: errorCenter,
                    loggerService: logger
                ),
                sessionExpiry: sessionService
            )
            let headerProvider = SupabaseHeaderProvider(sessionProvider: sessionService)
            let authRepository = AuthRepositoryImpl(
                remoteDataSource: AuthRemoteDataSourceImpl(httpService: httpService, headerProvider: headerProvider)
            )
            refreshUseCase.set(
                RefreshSessionUseCaseImpl(authRepository: authRepository, sessionService: sessionService)
            )
            let database = try AppDatabase.makeInMemory()
            let login = LoginUseCaseImpl(
                authRepository: authRepository,
                sessionService: sessionService,
                meRepository: MeRepositoryImpl(
                    remoteDataSource: MeRemoteDataSourceImpl(httpService: httpService, headerProvider: headerProvider),
                    database: database
                ),
                localDataRepository: LocalDataRepositoryImpl(database: database)
            )

            let context = try await login.execute(email: credentials.email, password: credentials.password)
            let engine = SyncEngineImpl(
                localDataSource: SyncLocalDataSourceImpl(database: database),
                remoteDataSource: SyncRemoteDataSourceImpl(httpService: httpService, headerProvider: headerProvider),
                deviceID: { nil },
                loggerService: logger
            )
            let report = try await engine.sync()
            try? await authRepository.signOut()

            #expect(!context.household.name.isEmpty)
            #expect(report.pushedCount == 0)
            #expect(report.pulledCount > 0)
            #expect(try await TestDatabase.count("recipes", in: database, where: "deleted_at IS NULL") > 0)
        }
    }

    private struct RefreshSessionUseCaseImplStub: RefreshSessionUseCase {
        func execute() async throws(KodaError) {
            throw KodaError(type: .internal, reason: "Refresh use case not wired.")
        }
    }
#endif
