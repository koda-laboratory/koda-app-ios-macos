import Foundation
import Synchronization

@testable import Koda

/// Scripted transport: every request is recorded and answered by `handler` (never the network).
final class FakeHTTPTransport: HTTPTransport, Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> (Int, Data)

    private let handler: Handler
    private let recorded = Mutex<[URLRequest]>([])

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    var requests: [URLRequest] {
        recorded.withLock { $0 }
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recorded.withLock { $0.append(request) }
        let (status, data) = try await handler(request)
        guard let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            throw URLError(.badURL)
        }
        return (data, response)
    }
}

/// JSON body helpers.
enum TestJSON {
    static func data(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    static func object(_ data: Data?) -> [String: Any] {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }
}

extension URLRequest {
    var path: String {
        url?.path ?? ""
    }

    var bodyObject: [String: Any] {
        TestJSON.object(httpBody)
    }

    var bearer: String? {
        value(forHTTPHeaderField: "Authorization")
    }
}

/// A value assigned after construction (breaks the HTTPService ↔ refresh use case cycle in tests).
final class LateBound<Value: Sendable>: Sendable {
    private let storage = Mutex<Value?>(nil)

    func set(_ value: Value) {
        storage.withLock { $0 = value }
    }

    var value: Value? {
        storage.withLock { $0 }
    }
}

/// Session storage in memory instead of the Keychain.
actor InMemorySessionRepository: SessionRepository {
    private var session: UserSession?

    init(session: UserSession? = nil) {
        self.session = session
    }

    func read() -> UserSession? {
        session
    }

    func save(_ session: UserSession) {
        self.session = session
    }

    func delete() {
        session = nil
    }
}

/// Keychain-like storage in memory.
actor InMemoryKeychainDataSource: KeychainPersistentDataSource {
    private var values: [String: Data] = [:]

    private func storageKey(_ type: (some Storable).Type, _ id: String) -> String {
        "\(type.storageIdentifier).\(id)"
    }

    func create(_ object: some Storable) throws {
        try update(object)
    }

    func read<Value: Storable>(_ type: Value.Type, id: String) throws -> Value? {
        guard let data = values[storageKey(type, id)] else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    func readAll<Value: Storable>(_ type: Value.Type) throws -> [Value] {
        try values.filter { $0.key.hasPrefix(type.storageIdentifier + ".") }.map {
            try JSONDecoder().decode(type, from: $0.value)
        }
    }

    func update(_ object: some Storable) throws {
        values[storageKey(type(of: object), object.id)] = try JSONEncoder().encode(object)
    }

    func delete(_ type: (some Storable).Type, id: String) {
        values.removeValue(forKey: storageKey(type, id))
    }

    func deleteAll(_ type: (some Storable).Type) {
        values = values.filter { !$0.key.hasPrefix(type.storageIdentifier + ".") }
    }

    func deleteStorage() {
        values.removeAll()
    }
}

/// Scheduler that records calls and never syncs.
actor RecordingSyncScheduler: SyncScheduling {
    private(set) var stopCount = 0
    private(set) var syncTriggers: [SyncTrigger] = []

    func start() {}

    func stop() {
        stopCount += 1
    }

    func requestSync(_ trigger: SyncTrigger) {
        syncTriggers.append(trigger)
    }

    func syncNow(_ trigger: SyncTrigger) -> SyncOutcome {
        syncTriggers.append(trigger)
        return .noData
    }

    func statusUpdates() -> AsyncStream<SyncStatus> {
        AsyncStream { $0.yield(.initial) }
    }
}

/// Polls an async condition until it holds or the timeout expires.
func waitUntil(
    timeout: Duration = .seconds(3),
    _ condition: @Sendable () async -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}
