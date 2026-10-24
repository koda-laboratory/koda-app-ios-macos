import Foundation
import GRDB

/// The local GRDB database, source of truth of the UI on iPhone and Mac.
///
/// Production uses a WAL `DatabasePool` in the App Group container (`group.com.kodalabs.app`) so the app,
/// App Intents and widgets share it; tests use an in-memory `DatabaseQueue` with the same migrations.
final class AppDatabase: Sendable {
    // MARK: - Properties

    let writer: any DatabaseWriter

    // MARK: - Lifecycle

    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// Opens (or creates) the shared on-disk database.
    static func makeShared(
        appGroup: String? = AppEnvironment.appGroup,
        fileManager: FileManager = .default
    ) throws -> AppDatabase {
        let directory = try AppDatabaseLocation.directory(appGroup: appGroup, fileManager: fileManager)
        let url = directory.appendingPathComponent("koda.sqlite")

        var configuration = Configuration()
        configuration.label = "KodaDatabase"
        // Readers in other processes (widgets) must not block on our writes for long.
        configuration.busyMode = .timeout(5)

        let pool = try DatabasePool(path: url.path, configuration: configuration)
        PlatformFileProtection.protectDatabase(at: url)
        return try AppDatabase(pool)
    }

    /// Empty in-memory database with every migration applied (tests and previews).
    static func makeInMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    // MARK: - Access

    func read<T: Sendable>(_ value: @escaping @Sendable (Database) throws -> T) async throws(KodaError) -> T {
        do {
            return try await writer.read(value)
        } catch {
            throw Self.map(error)
        }
    }

    @discardableResult
    func write<T: Sendable>(_ updates: @escaping @Sendable (Database) throws -> T) async throws(KodaError) -> T {
        do {
            return try await writer.write(updates)
        } catch {
            throw Self.map(error)
        }
    }

    /// Observes a query with `ValueObservation` and exposes it as an `AsyncStream`. The stream emits the current
    /// value first, then every committed change, and finishes when the observation fails.
    func observe<T: Sendable>(_ fetch: @escaping @Sendable (Database) throws -> T) -> AsyncStream<T> {
        let observation = ValueObservation.tracking(fetch)
        let reader = writer
        return AsyncStream { continuation in
            let cancellable = observation.start(
                in: reader,
                scheduling: .async(onQueue: DispatchQueue(label: "com.kodalabs.app.database.observation")),
                onError: { _ in continuation.finish() },
                onChange: { value in continuation.yield(value) }
            )
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }

    /// Deletes every row of every table (logout). The schema and migrations stay in place.
    func eraseAllData() async throws(KodaError) {
        try await write { db in
            for table in SyncedTable.allCases {
                try db.execute(sql: "DELETE FROM \(table.rawValue)")
            }
            try db.execute(sql: "DELETE FROM outbox")
            try db.execute(sql: "DELETE FROM pending_image_uploads")
            try db.execute(sql: "DELETE FROM me_members")
            try db.execute(sql: "DELETE FROM me_households")
            try db.execute(sql: "DELETE FROM me_profile")
            try db.execute(sql: "UPDATE sync_state SET cursor = 0, last_sync_at = NULL, household_id = NULL")
        }
    }

    // MARK: - Private Methods

    private static func map(_ error: any Error) -> KodaError {
        if let error = error as? KodaError { return error }
        if error is CancellationError {
            return KodaError(type: .apiRequestCancelled, reason: "The database operation was cancelled.")
        }
        return KodaError(type: .storage, reason: "Local database error: \(error)")
    }
}

// MARK: - Location

enum AppDatabaseLocation {
    /// `<App Group container>/Database`, or `Application Support/Koda/Database` when the container is unavailable
    /// (unsigned CI builds, missing entitlement).
    static func directory(appGroup: String?, fileManager: FileManager) throws -> URL {
        if let appGroup,
            let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup),
            let directory = try? prepare(container.appendingPathComponent("Database", isDirectory: true), fileManager)
        {
            return directory
        }

        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try prepare(applicationSupport.appendingPathComponent("Koda/Database", isDirectory: true), fileManager)
    }

    private static func prepare(_ directory: URL, _ fileManager: FileManager) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        PlatformFileProtection.protectDirectory(at: directory)
        return directory
    }
}
