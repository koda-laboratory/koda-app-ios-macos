import Foundation

/// What one sync run did.
struct SyncReport: Sendable, Equatable {
    var pushedCount = 0
    var rejectedCount = 0
    var pulledCount = 0
    var changedCount = 0
    var didResetCursor = false

    /// `true` when the local database changed (widgets and observers must refresh).
    var hasChanges: Bool { changedCount > 0 || didResetCursor }
}

/// The only component that moves product data between the local database and the backend.
protocol SyncEngine: Sendable {
    /// Pushes the outbox, then pulls from the stored cursor. Concurrent callers join the run in flight.
    @discardableResult
    func sync() async throws(KodaError) -> SyncReport
}

/// Single-flight sync: push the outbox in batches, then pull pages until `has_more` is false.
///
/// - Push: batches of 100 to `POST /sync/push` with this installation's `device_id`. A 2xx response settles the
///   whole batch: applied entries are removed and rejected ones are logged and dropped (the server wins and its
///   copy arrives with a pull). Network or auth failures keep the outbox intact.
/// - Pull: `GET /sync/pull` pages of 500 applied in one transaction each, without outbox entries, advancing the
///   cursor in the same transaction. `reset_required` wipes synced rows (keeping pending local changes and the
///   outbox) and pulls again from cursor 0.
actor SyncEngineImpl: SyncEngine {
    // MARK: - Properties

    private let localDataSource: any SyncLocalDataSource
    private let remoteDataSource: any SyncRemoteDataSource
    private let deviceID: @Sendable () async -> String?
    private let loggerService: any LoggerService
    private let clock: @Sendable () -> Date
    private let pushBatchSize: Int
    private let pullPageSize: Int

    private var inFlight: Task<SyncReport, any Error>?

    // MARK: - Lifecycle

    init(
        localDataSource: any SyncLocalDataSource,
        remoteDataSource: any SyncRemoteDataSource,
        deviceID: @escaping @Sendable () async -> String?,
        loggerService: any LoggerService,
        clock: @escaping @Sendable () -> Date = { .now },
        pushBatchSize: Int = 100,
        pullPageSize: Int = 500
    ) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
        self.deviceID = deviceID
        self.loggerService = loggerService
        self.clock = clock
        self.pushBatchSize = pushBatchSize
        self.pullPageSize = pullPageSize
    }

    // MARK: - Public Methods

    @discardableResult
    func sync() async throws(KodaError) -> SyncReport {
        let task: Task<SyncReport, any Error>
        if let inFlight {
            task = inFlight
        } else {
            task = Task { try await self.performSync() }
            inFlight = task
        }

        do {
            let report = try await task.value
            clearInFlight(task)
            return report
        } catch {
            clearInFlight(task)
            throw KodaErrorMapper.map(error)
        }
    }

    // MARK: - Run

    private func clearInFlight(_ task: Task<SyncReport, any Error>) {
        if inFlight == task {
            inFlight = nil
        }
    }

    private func performSync() async throws -> SyncReport {
        var report = SyncReport()
        try await push(into: &report)
        try await pull(into: &report)
        loggerService.info(
            "🔄 [SYNC] Completed.",
            attributes: [
                "sync.pushed": String(report.pushedCount),
                "sync.rejected": String(report.rejectedCount),
                "sync.pulled": String(report.pulledCount),
                "sync.changed": String(report.changedCount),
            ]
        )
        return report
    }

    private func push(into report: inout SyncReport) async throws {
        let deviceID = await deviceID()
        var previousBatch: [Int64] = []

        while true {
            try Task.checkCancellation()
            let batch = try await localDataSource.pendingMutations(limit: pushBatchSize)
            guard !batch.isEmpty else { return }
            let outboxIDs = batch.map(\.outboxID)
            // Defensive: never resend the same batch forever if the outbox could not be cleared.
            guard outboxIDs != previousBatch else {
                throw KodaError(type: .storage, reason: "The outbox did not advance after a push.")
            }
            previousBatch = outboxIDs

            let body = SyncPushRequestDTO(
                deviceId: deviceID,
                mutations: batch.map { mutation in
                    SyncMutationDTO(
                        table: mutation.table,
                        id: mutation.rowID,
                        op: mutation.op,
                        fields: mutation.fields,
                        clientTs: mutation.clientTimestamp
                    )
                }
            )

            let response: SyncPushResponseDTO
            do {
                response = try await remoteDataSource.push(body)
            } catch {
                try? await localDataSource.recordFailure(outboxIDs: outboxIDs, reason: error.reason)
                throw error
            }

            let rejected = response.rejected.map { RejectedMutation(table: $0.table, rowID: $0.id, reason: $0.reason) }
            for rejection in response.rejected {
                loggerService.warning(
                    "⚠️ [SYNC] Mutation rejected; the server version wins.",
                    attributes: [
                        "sync.table": rejection.table ?? "unknown",
                        "sync.reason": rejection.reason,
                        "sync.code": rejection.code ?? "none",
                    ]
                )
            }
            try await localDataSource.completeMutations(outboxIDs: outboxIDs, rejected: rejected)
            report.pushedCount += response.applied.count
            report.rejectedCount += response.rejected.count
        }
    }

    private func pull(into report: inout SyncReport) async throws {
        var cursor = try await localDataSource.cursor()
        var hasMore = true

        while hasMore {
            try Task.checkCancellation()
            let page = try await remoteDataSource.pull(cursor: cursor, limit: pullPageSize)

            if page.resetRequired {
                guard !report.didResetCursor else {
                    throw KodaError(type: .server, reason: "The server asked for a second resync in one run.")
                }
                loggerService.warning("♻️ [SYNC] Cursor older than purged tombstones; full resync from 0.")
                try await localDataSource.resetForFullResync()
                report.didResetCursor = true
                cursor = 0
                continue
            }

            let changed = try await localDataSource.apply(page, syncedAt: clock())
            report.pulledCount += page.changes.values.reduce(0) { $0 + $1.count }
            report.changedCount += changed

            guard !page.hasMore || page.cursor > cursor else {
                throw KodaError(type: .server, reason: "The pull cursor did not advance.")
            }
            cursor = page.cursor
            hasMore = page.hasMore
        }
    }
}
