import Foundation
import Synchronization
import Testing

@testable import Koda

@Suite("Session: restore, refresh, forced login, login and logout")
struct SessionLifecycleTests {
    private let now = Date(timeIntervalSince1970: 1_792_663_200)

    private func meDataSource(_ stack: TestHTTPStack) -> MeRemoteDataSourceImpl {
        MeRemoteDataSourceImpl(httpService: stack.httpService, headerProvider: stack.headerProvider)
    }

    @Test("Restoring at launch reads the Keychain session without any request")
    func restoreWithoutNetwork() async throws {
        let session = TestHTTPStack.session(expiresAt: now.addingTimeInterval(-600))
        let stack = TestHTTPStack(session: session, now: now) { _ in (500, Data()) }

        let restored = await RestoreSessionUseCaseImpl(sessionService: stack.sessionService).execute()

        #expect(restored == session)
        #expect(stack.transport.requests.isEmpty)
    }

    @Test("A token expiring within 60 s is refreshed before the request")
    func proactiveRefresh() async throws {
        let session = TestHTTPStack.session(expiresAt: now.addingTimeInterval(30))
        let stack = TestHTTPStack(session: session, now: now) { request in
            if request.path.hasSuffix("/auth/v1/token") {
                return (200, TestHTTPStack.sessionJSON(access: "access-2", refresh: "refresh-2"))
            }
            return (200, TestHTTPStack.meJSON())
        }

        _ = try await meDataSource(stack).fetchMe()

        let requests = stack.transport.requests
        #expect(requests.map(\.path).map { $0.hasSuffix("/auth/v1/token") } == [true, false])
        #expect(requests.first?.url?.query == "grant_type=refresh_token")
        #expect(requests.first?.bodyObject["refresh_token"] as? String == "refresh-1")
        #expect(requests.last?.bearer == "Bearer access-2")
        #expect(try await stack.sessionService.current()?.refreshToken == "refresh-2")
    }

    @Test("A 401 refreshes once and retries with the new token")
    func refreshOnUnauthorized() async throws {
        let session = TestHTTPStack.session(expiresAt: now.addingTimeInterval(3600))
        let stack = TestHTTPStack(session: session, now: now) { request in
            if request.path.hasSuffix("/auth/v1/token") {
                return (200, TestHTTPStack.sessionJSON(access: "access-2", refresh: "refresh-2"))
            }
            if request.bearer == "Bearer access-1" {
                return (401, TestJSON.data(["error": ["code": "unauthorized", "message": "Invalid or expired token"]]))
            }
            return (200, TestHTTPStack.meJSON())
        }

        let response = try await meDataSource(stack).fetchMe()

        #expect(response.households.first?.name == "Casa")
        #expect(stack.transport.requests.map(\.bearer) == ["Bearer access-1", nil, "Bearer access-2"])
    }

    @Test("invalid_grant forces login and keeps the local database and outbox")
    func invalidGrantKeepsLocalData() async throws {
        let session = TestHTTPStack.session(expiresAt: now.addingTimeInterval(3600))
        let stack = TestHTTPStack(session: session, now: now) { request in
            if request.path.hasSuffix("/auth/v1/token") {
                return (400, TestJSON.data(["error": "invalid_grant", "error_description": "Invalid Refresh Token"]))
            }
            return (401, TestJSON.data(["error": ["code": "unauthorized", "message": "expired"]]))
        }
        let events = await stack.errorCenter.events()
        let received = Mutex<[KodaErrorAction]>([])
        let listener = Task {
            for await event in events {
                received.withLock { $0.append(event.action) }
            }
        }
        defer { listener.cancel() }

        let database = try await TestDatabase.make()
        let shopping = ShoppingRepositoryImpl(database: database, writer: LocalMutationWriter())
        try await shopping.addEntry(NewShoppingEntry(item: .text("Pan")))

        await #expect(throws: KodaError.self) { try await meDataSource(stack).fetchMe() }
        #expect(await waitUntil { received.withLock { $0.contains(.forceLogin) } })

        let scheduler = RecordingSyncScheduler()
        await ExpireSessionUseCaseImpl(syncScheduler: scheduler, sessionService: stack.sessionService).execute()

        #expect(try await stack.sessionService.current() == nil)
        #expect(await scheduler.stopCount == 1)
        #expect(try await TestDatabase.count("shopping_entries", in: database) == 1)
        #expect(try await TestDatabase.count("outbox", in: database) == 1)
    }

    @Test("Login stores the session and caches /me; another user's data is wiped first")
    func loginCachesHousehold() async throws {
        let newUser = "44444444-4444-4444-8444-444444444444"
        let stack = TestHTTPStack(session: nil, now: now) { request in
            if request.path.hasSuffix("/auth/v1/token") {
                return (200, TestHTTPStack.sessionJSON(access: "a", refresh: "r", userID: newUser))
            }
            return (200, TestHTTPStack.meJSON(userID: newUser, householdID: TestDatabase.householdID))
        }
        let database = try await TestDatabase.make()
        try await ShoppingRepositoryImpl(database: database, writer: LocalMutationWriter())
            .addEntry(NewShoppingEntry(item: .text("Del usuario anterior")))
        let meRepository = MeRepositoryImpl(remoteDataSource: meDataSource(stack), database: database)
        let login = LoginUseCaseImpl(
            authRepository: stack.authRepository,
            sessionService: stack.sessionService,
            meRepository: meRepository,
            localDataRepository: LocalDataRepositoryImpl(database: database)
        )

        let context = try await login.execute(email: " Test@Example.com ", password: "secret")

        #expect(context.userID.uuidString.lowercased() == newUser)
        #expect(context.household.name == "Casa")
        #expect(context.household.members.count == 1)
        #expect(try await stack.sessionService.current()?.userId == newUser)
        #expect(stack.transport.requests.first?.bodyObject["email"] as? String == "test@example.com")
        #expect(try await TestDatabase.count("shopping_entries", in: database) == 0)
        #expect(
            try await TestDatabase.string("SELECT household_id FROM sync_state", in: database)
                == TestDatabase.householdID
        )
    }

    @Test("Logout removes the device, revokes the session and clears the Keychain and the database")
    func logoutClearsEverything() async throws {
        let session = TestHTTPStack.session(expiresAt: now.addingTimeInterval(3600))
        let stack = TestHTTPStack(session: session, now: now) { request in
            (request.httpMethod == "DELETE" || request.path.hasSuffix("/logout")) ? (204, Data()) : (500, Data())
        }
        let database = try await TestDatabase.make()
        try await ShoppingRepositoryImpl(database: database, writer: LocalMutationWriter())
            .addEntry(NewShoppingEntry(item: .text("Pan")))
        let keychain = InMemoryKeychainDataSource()
        let deviceRepository = DeviceRepositoryImpl(
            remoteDataSource: DeviceRemoteDataSourceImpl(
                httpService: stack.httpService,
                headerProvider: stack.headerProvider
            ),
            persistentDataSource: keychain
        )
        let deviceID = try await deviceRepository.installationID()
        let scheduler = RecordingSyncScheduler()
        let logout = LogoutUseCaseImpl(
            syncScheduler: scheduler,
            deviceRepository: deviceRepository,
            authRepository: stack.authRepository,
            sessionService: stack.sessionService,
            localDataRepository: LocalDataRepositoryImpl(database: database)
        )

        try await logout.execute()

        let requests = stack.transport.requests
        #expect(requests.first?.httpMethod == "DELETE")
        #expect(requests.first?.path.hasSuffix("/functions/v1/api/devices/\(deviceID)") == true)
        #expect(requests.last?.path.hasSuffix("/auth/v1/logout") == true)
        #expect(requests.allSatisfy { $0.bearer == "Bearer access-1" })
        #expect(await scheduler.stopCount == 1)
        #expect(try await stack.sessionService.current() == nil)
        #expect(try await TestDatabase.count("shopping_entries", in: database) == 0)
        #expect(try await TestDatabase.count("outbox", in: database) == 0)
        #expect(try await TestDatabase.count("me_profile", in: database) == 0)
    }

    @Test("Logout still clears local data when offline")
    func logoutOffline() async throws {
        let session = TestHTTPStack.session(expiresAt: now.addingTimeInterval(3600))
        let stack = TestHTTPStack(session: session, now: now) { _ in
            throw URLError(.notConnectedToInternet)
        }
        let database = try await TestDatabase.make()
        let logout = LogoutUseCaseImpl(
            syncScheduler: RecordingSyncScheduler(),
            deviceRepository: DeviceRepositoryImpl(
                remoteDataSource: DeviceRemoteDataSourceImpl(
                    httpService: stack.httpService,
                    headerProvider: stack.headerProvider
                ),
                persistentDataSource: InMemoryKeychainDataSource()
            ),
            authRepository: stack.authRepository,
            sessionService: stack.sessionService,
            localDataRepository: LocalDataRepositoryImpl(database: database)
        )

        try await logout.execute()

        #expect(try await stack.sessionService.current() == nil)
        #expect(try await TestDatabase.count("me_profile", in: database) == 0)
    }
}

@Suite("Device registration")
struct DeviceRegistrationTests {
    @Test("PUT /devices sends the installation id, hex token, platform, APNs environment and version")
    func registrationPayload() async throws {
        let stack = TestHTTPStack(session: TestHTTPStack.session(expiresAt: .now.addingTimeInterval(3600))) { _ in
            (200, TestJSON.data(["id": "ignored"]))
        }
        let keychain = InMemoryKeychainDataSource()
        let repository = DeviceRepositoryImpl(
            remoteDataSource: DeviceRemoteDataSourceImpl(
                httpService: stack.httpService,
                headerProvider: stack.headerProvider
            ),
            persistentDataSource: keychain,
            environment: DeviceEnvironment(platform: "ios", apnsEnvironment: "sandbox", appVersion: "1.0.0 (7)")
        )
        let useCase = RegisterDeviceUseCaseImpl(deviceRepository: repository, sessionService: stack.sessionService)

        try await useCase.execute(apnsToken: Data([0x0A, 0xFF, 0x00, 0x7B]))

        let request = try #require(stack.transport.requests.first)
        let body = request.bodyObject
        #expect(request.httpMethod == "PUT")
        #expect(request.path.hasSuffix("/functions/v1/api/devices"))
        #expect(body["apns_token"] as? String == "0aff007b")
        #expect(body["platform"] as? String == "ios")
        #expect(body["apns_env"] as? String == "sandbox")
        #expect(body["app_version"] as? String == "1.0.0 (7)")
        let id = try #require(body["id"] as? String)
        #expect(UUID(uuidString: id) != nil)
        // The installation id is stable across calls (kept in the Keychain).
        #expect(try await repository.installationID() == id)
        #expect(
            try await DeviceRepositoryImpl(
                remoteDataSource: DeviceRemoteDataSourceImpl(
                    httpService: stack.httpService,
                    headerProvider: stack.headerProvider
                ),
                persistentDataSource: keychain
            ).installationID() == id
        )
    }

    @Test("Nothing is uploaded while signed out")
    func signedOutSkipsRegistration() async throws {
        let stack = TestHTTPStack(session: nil) { _ in (200, Data()) }
        let repository = DeviceRepositoryImpl(
            remoteDataSource: DeviceRemoteDataSourceImpl(
                httpService: stack.httpService,
                headerProvider: stack.headerProvider
            ),
            persistentDataSource: InMemoryKeychainDataSource()
        )

        try await RegisterDeviceUseCaseImpl(deviceRepository: repository, sessionService: stack.sessionService)
            .execute(apnsToken: Data([1, 2, 3]))

        #expect(stack.transport.requests.isEmpty)
    }

    @Test("This build reports a valid APNs environment")
    func apnsEnvironmentIsValid() {
        #expect(["sandbox", "production"].contains(PlatformInfo.apnsEnvironment))
    }
}
