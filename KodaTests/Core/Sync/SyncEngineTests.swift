import Foundation
import GRDB
import Synchronization
import Testing

@testable import Koda

@Suite("SyncEngine push/pull over a fake transport")
struct SyncEngineTests {
    private static let deviceID = "33333333-3333-4333-8333-333333333333"

    private func makeEngine(
        database: AppDatabase,
        handler: @escaping FakeHTTPTransport.Handler
    ) -> (SyncEngineImpl, FakeHTTPTransport) {
        let session = TestHTTPStack.session(expiresAt: .now.addingTimeInterval(3600))
        let stack = TestHTTPStack(session: session, handler: handler)
        let engine = SyncEngineImpl(
            localDataSource: SyncLocalDataSourceImpl(database: database),
            remoteDataSource: SyncRemoteDataSourceImpl(
                httpService: stack.httpService,
                headerProvider: stack.headerProvider
            ),
            deviceID: { Self.deviceID },
            loggerService: SilentLoggerService()
        )
        return (engine, stack.transport)
    }

    /// Accepts every pushed mutation and answers pulls with an empty page.
    private static func acceptingHandler(_ request: URLRequest) -> (Int, Data) {
        if request.path.hasSuffix("/sync/push") {
            let mutations = request.bodyObject["mutations"] as? [[String: Any]] ?? []
            let applied = mutations.enumerated().map { index, mutation in
                ["table": mutation["table"] ?? "", "id": mutation["id"] ?? "", "server_seq": index + 1]
            }
            return (200, TestJSON.data(["applied": applied, "rejected": [], "cursor": applied.count]))
        }
        return (200, ServerRows.pull([:], cursor: 0))
    }

    private func seedStores(_ count: Int, in database: AppDatabase) async throws {
        let writer = LocalMutationWriter()
        try await database.write { db in
            for index in 0..<count {
                try writer.save(
                    StoreRecord(id: ServerRows.uuid(index), householdId: "", name: "Store \(index)"),
                    in: db
                )
            }
        }
    }

    @Test("Pushes the outbox in batches of 100 with the device id and empties it")
    func pushBatches() async throws {
        let database = try await TestDatabase.make()
        try await seedStores(250, in: database)
        let (engine, transport) = makeEngine(database: database, handler: Self.acceptingHandler)

        let report = try await engine.sync()

        let pushes = transport.requests.filter { $0.path.hasSuffix("/sync/push") }
        #expect(pushes.map { ($0.bodyObject["mutations"] as? [Any])?.count ?? 0 } == [100, 100, 50])
        #expect(pushes.allSatisfy { $0.bodyObject["device_id"] as? String == Self.deviceID })
        #expect(pushes.allSatisfy { $0.httpMethod == "POST" && $0.bearer == "Bearer access-1" })
        let first = try #require((pushes.first?.bodyObject["mutations"] as? [[String: Any]])?.first)
        #expect(first["op"] as? String == "upsert")
        #expect(first["table"] as? String == "stores")
        #expect((first["fields"] as? [String: Any])?["name"] as? String == "Store 0")
        #expect(first["client_ts"] is String)
        #expect(report.pushedCount == 250)
        #expect(try await TestDatabase.count("outbox", in: database) == 0)
    }

    @Test("Pulls every page until has_more is false, applies rows without outbox and stores the cursor")
    func pullPaging() async throws {
        let database = try await TestDatabase.make()
        let product = ServerRows.uuid(1)
        let recipe = ServerRows.uuid(2)
        let (engine, transport) = makeEngine(database: database) { request in
            guard request.path.hasSuffix("/sync/pull") else { return (500, Data()) }
            let cursor = URLComponents(url: request.url ?? URL(fileURLWithPath: "/"), resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "cursor" }?.value
            if cursor == "0" {
                // Child before parent: application is order-independent.
                return (
                    200,
                    ServerRows.pull(
                        [
                            "recipe_ingredients": [
                                ServerRows.ingredient(
                                    ServerRows.uuid(3),
                                    recipe: recipe,
                                    product: product,
                                    quantity: 200,
                                    seq: 3
                                )
                            ]
                        ],
                        cursor: 3,
                        hasMore: true
                    )
                )
            }
            return (
                200,
                ServerRows.pull(
                    [
                        "products": [ServerRows.product(product, name: "Pollo", seq: 4)],
                        "recipes": [ServerRows.recipe(recipe, name: "Pollo al horno", seq: 5)],
                        "unknown_future_table": [["id": "x"]],
                    ],
                    cursor: 5
                )
            )
        }

        let report = try await engine.sync()

        let pulls = transport.requests.filter { $0.path.hasSuffix("/sync/pull") }
        #expect(pulls.count == 2)
        #expect(pulls.allSatisfy { $0.url?.query?.contains("limit=500") == true })
        #expect(report.changedCount == 3)
        #expect(try await TestDatabase.count("outbox", in: database) == 0)
        #expect(try await TestDatabase.string("SELECT cursor FROM sync_state", in: database) == "5")

        // JSON arrays and booleans are stored in their local form and map back to the domain.
        let recipes = RecipeRepositoryImpl(database: database, writer: LocalMutationWriter())
        var details = recipes.observeRecipeDetail(id: try #require(UUID(uuidString: recipe))).makeAsyncIterator()
        let detail = try #require(await details.next() ?? nil)
        #expect(detail.recipe.mealTypes == [.lunch, .dinner])
        #expect(detail.recipe.steps == ["Cortar", "Hornear"])
        #expect(detail.recipe.isFavorite)
        #expect(detail.ingredients.map(\.productName) == ["Pollo"])
    }

    @Test("An older copy never overwrites a newer one and tombstones apply")
    func pullIsOrderIndependent() async throws {
        let database = try await TestDatabase.make()
        let recipe = ServerRows.uuid(7)
        let pages = Mutex([
            ServerRows.pull(["recipes": [ServerRows.recipe(recipe, name: "Nueva", seq: 10)]], cursor: 10),
            ServerRows.pull(["recipes": [ServerRows.recipe(recipe, name: "Vieja", seq: 8)]], cursor: 11),
            ServerRows.pull(
                ["recipes": [ServerRows.recipe(recipe, name: "Nueva", seq: 12, deleted: true)]],
                cursor: 12
            ),
        ])
        let (engine, _) = makeEngine(database: database) { _ in
            (200, pages.withLock { $0.isEmpty ? ServerRows.pull([:], cursor: 12) : $0.removeFirst() })
        }

        try await engine.sync()
        try await engine.sync()
        #expect(try await TestDatabase.string("SELECT name FROM recipes", in: database) == "Nueva")

        try await engine.sync()
        #expect(try await TestDatabase.count("recipes", in: database, where: "deleted_at IS NOT NULL") == 1)
    }

    @Test("reset_required keeps pending local rows and the outbox, and drops the rest")
    func resetKeepsPendingChanges() async throws {
        let database = try await TestDatabase.make()
        try await database.writer.write { db in
            try db.execute(sql: "UPDATE sync_state SET cursor = 42")
            try db.execute(
                sql: "INSERT INTO stores (id, household_id, name, server_seq) VALUES (?, ?, 'Vieja', 40)",
                arguments: [ServerRows.uuid(90), TestDatabase.householdID]
            )
        }
        try await seedStores(1, in: database)

        try await SyncLocalDataSourceImpl(database: database).resetForFullResync()

        #expect(try await TestDatabase.count("stores", in: database, where: "id = '\(ServerRows.uuid(90))'") == 0)
        #expect(try await TestDatabase.count("stores", in: database, where: "id = '\(ServerRows.uuid(0))'") == 1)
        #expect(try await TestDatabase.count("outbox", in: database) == 1)
        #expect(try await TestDatabase.string("SELECT cursor FROM sync_state", in: database) == "0")
    }

    @Test("reset_required makes the engine pull again from cursor 0")
    func resetRequiredRestartsFromZero() async throws {
        let database = try await TestDatabase.make()
        try await database.writer.write { db in try db.execute(sql: "UPDATE sync_state SET cursor = 42") }
        let cursors = Mutex<[String]>([])
        let (engine, _) = makeEngine(database: database) { request in
            let query = request.url?.query ?? ""
            let cursor = query.components(separatedBy: "&").first { $0.hasPrefix("cursor=") } ?? ""
            cursors.withLock { $0.append(cursor) }
            if cursor == "cursor=42" {
                return (200, ServerRows.pull([:], cursor: 42, resetRequired: true))
            }
            let row = ServerRows.product(ServerRows.uuid(91), name: "Leche", seq: 3)
            return (200, ServerRows.pull(["products": [row]], cursor: 3))
        }

        let report = try await engine.sync()

        #expect(report.didResetCursor)
        #expect(cursors.withLock { $0 } == ["cursor=42", "cursor=0"])
        #expect(try await TestDatabase.count("products", in: database) == 1)
        #expect(try await TestDatabase.string("SELECT cursor FROM sync_state", in: database) == "3")
    }

    @Test("A failed push keeps the outbox and records the attempt")
    func failedPushKeepsOutbox() async throws {
        let database = try await TestDatabase.make()
        try await seedStores(1, in: database)
        let (engine, transport) = makeEngine(database: database) { _ in
            throw URLError(.notConnectedToInternet)
        }

        await #expect(throws: KodaError.self) { try await engine.sync() }

        #expect(transport.requests.count == 1)
        #expect(
            try await TestDatabase.count("outbox", in: database, where: "attempts = 1 AND last_error IS NOT NULL") == 1
        )
    }

    @Test("Rejected mutations are dropped; never-synced rows without a server copy are removed locally")
    func rejectedMutations() async throws {
        let database = try await TestDatabase.make()
        try await seedStores(2, in: database)
        let (engine, _) = makeEngine(database: database) { request in
            guard request.path.hasSuffix("/sync/push") else { return (200, ServerRows.pull([:], cursor: 0)) }
            return (
                200,
                TestJSON.data([
                    "applied": [],
                    "rejected": [
                        ["table": "stores", "id": ServerRows.uuid(0), "reason": "missing_reference", "code": "23503"],
                        ["table": "stores", "id": ServerRows.uuid(1), "reason": "stale", "server_seq": 9],
                    ],
                    "cursor": NSNull(),
                ])
            )
        }

        let report = try await engine.sync()

        #expect(report.rejectedCount == 2)
        #expect(try await TestDatabase.count("outbox", in: database) == 0)
        #expect(try await TestDatabase.count("stores", in: database, where: "id = '\(ServerRows.uuid(0))'") == 0)
        #expect(try await TestDatabase.count("stores", in: database, where: "id = '\(ServerRows.uuid(1))'") == 1)
    }

    @Test("A pulled row keeps pending local changes on top until they are pushed")
    func pullRebasesPendingChanges() async throws {
        let database = try await TestDatabase.make()
        let local = SyncLocalDataSourceImpl(database: database)
        let id = ServerRows.uuid(5)
        try await database.writer.write { db in
            try db.execute(
                sql: "INSERT INTO stores (id, household_id, name, server_seq) VALUES (?, ?, 'Aldi', 1)",
                arguments: [id, TestDatabase.householdID]
            )
        }
        let writer = LocalMutationWriter()
        try await database.write { db in
            var store = try StoreRecord.fetchOne(db, key: id) ?? StoreRecord(id: id, householdId: "", name: "")
            store.name = "Aldi Centro"
            try writer.save(store, in: db)
        }
        let page = try JSONDecoder().decode(
            SyncPullResponseDTO.self,
            from: ServerRows.pull(
                ["stores": [ServerRows.sync(id, seq: 2).merging(["name": "Aldi", "color": "#00f"]) { $1 }]],
                cursor: 2
            )
        )

        _ = try await local.apply(page, syncedAt: .now)

        #expect(try await TestDatabase.string("SELECT name FROM stores", in: database) == "Aldi Centro")
        // The pending upsert carries the whole row (row last-writer-wins), so it also wins locally until pushed.
        #expect(try await TestDatabase.string("SELECT color FROM stores", in: database) == nil)
        #expect(try await TestDatabase.string("SELECT server_seq FROM stores", in: database) == "2")
        #expect(try await TestDatabase.count("outbox", in: database) == 1)
    }

    @Test("Concurrent sync calls share one run (single-flight)")
    func singleFlight() async throws {
        let database = try await TestDatabase.make()
        try await seedStores(3, in: database)
        let (engine, transport) = makeEngine(database: database) { request in
            try await Task.sleep(for: .milliseconds(50))
            return Self.acceptingHandler(request)
        }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<6 {
                group.addTask { _ = try? await engine.sync() }
            }
        }

        #expect(transport.requests.filter { $0.path.hasSuffix("/sync/push") }.count == 1)
        #expect(transport.requests.filter { $0.path.hasSuffix("/sync/pull") }.count == 1)
    }
}
