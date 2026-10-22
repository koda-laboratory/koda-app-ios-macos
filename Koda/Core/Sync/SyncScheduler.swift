import Foundation

/// Decides **when** to sync and publishes the sync status for the offline indicator.
protocol SyncScheduling: Sendable {
    /// Starts the triggers (reachability, outbox debounce). Idempotent.
    func start() async
    /// Stops every trigger (logout or forced login). Pending changes stay in the outbox.
    func stop() async
    /// Fire-and-forget request. `.localChange` is debounced; the other triggers run right away.
    func requestSync(_ trigger: SyncTrigger) async
    /// Runs (or joins) a sync and reports the outcome to background callers.
    @discardableResult
    func syncNow(_ trigger: SyncTrigger) async -> SyncOutcome
    /// Current status first, then every change.
    func statusUpdates() async -> AsyncStream<SyncStatus>
}

/// Triggers: launch, foreground, reconnect (`NWPathMonitor`), 2 s after local writes (outbox growth), silent
/// push, `BGAppRefreshTask` and manual refresh. After each sync it schedules the next background refresh and,
/// when data changed, reloads widget timelines.
actor SyncSchedulerImpl: SyncScheduling {
    // MARK: - Properties

    private let engine: any SyncEngine
    private let localDataSource: any SyncLocalDataSource
    private let reachability: any NetworkReachabilityMonitoring
    private let widgetReloader: any WidgetTimelineReloading
    private let backgroundRefresh: any BackgroundRefreshScheduling
    private let isSignedIn: @Sendable () async -> Bool
    private let loggerService: any LoggerService
    private let debounceInterval: Duration
    private let sleep: @Sendable (Duration) async throws -> Void
    private let clock: @Sendable () -> Date

    private var isRunning = false
    private var status = SyncStatus.initial
    private var lastPendingCount: Int?
    private var localChangeDuringSync = false
    private var debounceTask: Task<Void, Never>?
    private var monitorTasks: [Task<Void, Never>] = []
    private var continuations: [UUID: AsyncStream<SyncStatus>.Continuation] = [:]

    // MARK: - Lifecycle

    init(
        engine: any SyncEngine,
        localDataSource: any SyncLocalDataSource,
        reachability: any NetworkReachabilityMonitoring,
        widgetReloader: any WidgetTimelineReloading,
        backgroundRefresh: any BackgroundRefreshScheduling,
        isSignedIn: @escaping @Sendable () async -> Bool,
        loggerService: any LoggerService,
        debounceInterval: Duration = .seconds(2),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.engine = engine
        self.localDataSource = localDataSource
        self.reachability = reachability
        self.widgetReloader = widgetReloader
        self.backgroundRefresh = backgroundRefresh
        self.isSignedIn = isSignedIn
        self.loggerService = loggerService
        self.debounceInterval = debounceInterval
        self.sleep = sleep
        self.clock = clock
    }

    // MARK: - Lifecycle Control

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let reachabilityUpdates = reachability.updates()
        let pendingCounts = localDataSource.observePendingCount()
        monitorTasks = [
            Task { [weak self] in
                for await isOnline in reachabilityUpdates {
                    await self?.reachabilityChanged(isOnline: isOnline)
                }
            },
            Task { [weak self] in
                for await count in pendingCounts {
                    await self?.pendingCountChanged(count)
                }
            },
        ]
    }

    func stop() {
        isRunning = false
        debounceTask?.cancel()
        debounceTask = nil
        monitorTasks.forEach { $0.cancel() }
        monitorTasks = []
        lastPendingCount = nil
    }

    // MARK: - Triggers

    func requestSync(_ trigger: SyncTrigger) {
        guard isRunning else { return }
        if trigger == .localChange {
            scheduleDebouncedSync()
            return
        }
        Task { await self.syncNow(trigger) }
    }

    @discardableResult
    func syncNow(_ trigger: SyncTrigger) async -> SyncOutcome {
        guard await isSignedIn() else { return .skipped }

        if trigger != .localChange {
            debounceTask?.cancel()
            debounceTask = nil
        }
        update { $0.isSyncing = true }
        loggerService.debug("🔄 [SYNC] Triggered.", attributes: ["sync.trigger": trigger.rawValue])

        let outcome: SyncOutcome
        do {
            let report = try await engine.sync()
            if report.hasChanges {
                widgetReloader.reloadAllTimelines()
            }
            update {
                $0.lastSyncAt = clock()
                $0.lastErrorType = nil
                $0.isOnline = true
            }
            outcome = report.hasChanges ? .newData : .noData
        } catch {
            if error.type == .noInternet {
                update { $0.isOnline = false }
            }
            update { $0.lastErrorType = error.type }
            loggerService.warning(
                "⚠️ [SYNC] Failed; pending changes stay in the outbox.",
                attributes: ["error.type": error.type.rawValue, "sync.trigger": trigger.rawValue]
            )
            outcome = error.type == .apiRequestCancelled ? .noData : .failed
        }

        update { $0.isSyncing = false }
        backgroundRefresh.scheduleNextRefresh()
        await refreshPendingCount()

        if localChangeDuringSync {
            localChangeDuringSync = false
            if isRunning, status.pendingChanges > 0 {
                scheduleDebouncedSync()
            }
        }
        return outcome
    }

    // MARK: - Status

    func statusUpdates() -> AsyncStream<SyncStatus> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<SyncStatus>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuations[id] = continuation
        continuation.yield(status)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    // MARK: - Private Methods

    private func reachabilityChanged(isOnline: Bool) {
        let wasOnline = status.isOnline
        update { $0.isOnline = isOnline }
        if isOnline, !wasOnline {
            requestSync(.reconnect)
        }
    }

    private func pendingCountChanged(_ count: Int) {
        let previous = lastPendingCount
        lastPendingCount = count
        update { $0.pendingChanges = count }

        // The outbox only grows with local writes (app, intents): sync them after a short quiet period.
        guard let previous, count > previous else { return }
        if status.isSyncing {
            localChangeDuringSync = true
        }
        requestSync(.localChange)
    }

    private func scheduleDebouncedSync() {
        debounceTask?.cancel()
        let interval = debounceInterval
        let sleep = sleep
        debounceTask = Task { [weak self] in
            do {
                try await sleep(interval)
            } catch {
                return
            }
            await self?.runDebouncedSync()
        }
    }

    private func runDebouncedSync() async {
        debounceTask = nil
        guard isRunning else { return }
        await syncNow(.localChange)
    }

    private func refreshPendingCount() async {
        guard let count = try? await localDataSource.pendingCount() else { return }
        update { $0.pendingChanges = count }
    }

    private func update(_ change: (inout SyncStatus) -> Void) {
        var newStatus = status
        change(&newStatus)
        guard newStatus != status else { return }
        status = newStatus
        for continuation in continuations.values {
            continuation.yield(newStatus)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
