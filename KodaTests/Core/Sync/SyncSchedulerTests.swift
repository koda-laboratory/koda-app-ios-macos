import Foundation
import Synchronization
import Testing

@testable import Koda

@Suite("SyncScheduler triggers and status")
struct SyncSchedulerTests {
    private final class CountingEngine: SyncEngine {
        private let calls = Mutex(0)
        let report: SyncReport

        init(report: SyncReport = SyncReport()) {
            self.report = report
        }

        var callCount: Int { calls.withLock { $0 } }

        func sync() async throws(KodaError) -> SyncReport {
            calls.withLock { $0 += 1 }
            return report
        }
    }

    private final class ControlledReachability: NetworkReachabilityMonitoring {
        let stream: AsyncStream<Bool>
        let continuation: AsyncStream<Bool>.Continuation

        init() {
            (stream, continuation) = AsyncStream<Bool>.makeStream()
        }

        func updates() -> AsyncStream<Bool> { stream }
    }

    private final class CountingReloader: WidgetTimelineReloading, BackgroundRefreshScheduling {
        private let reloads = Mutex(0)
        private let schedules = Mutex(0)

        var reloadCount: Int { reloads.withLock { $0 } }
        var scheduleCount: Int { schedules.withLock { $0 } }

        func reloadAllTimelines() { reloads.withLock { $0 += 1 } }

        func scheduleNextRefresh() { schedules.withLock { $0 += 1 } }
    }

    private func makeScheduler(
        engine: CountingEngine,
        database: AppDatabase,
        reachability: ControlledReachability = ControlledReachability(),
        reloader: CountingReloader = CountingReloader(),
        signedIn: Bool = true
    ) -> SyncSchedulerImpl {
        SyncSchedulerImpl(
            engine: engine,
            localDataSource: SyncLocalDataSourceImpl(database: database),
            reachability: reachability,
            widgetReloader: reloader,
            backgroundRefresh: reloader,
            isSignedIn: { signedIn },
            loggerService: SilentLoggerService(),
            debounceInterval: .milliseconds(20)
        )
    }

    @Test("A local write triggers one debounced sync")
    func localWriteTriggersDebouncedSync() async throws {
        let database = try await TestDatabase.make()
        let engine = CountingEngine()
        let scheduler = makeScheduler(engine: engine, database: database)
        await scheduler.start()
        try await Task.sleep(for: .milliseconds(50))  // let the outbox observation deliver its initial count

        let shopping = ShoppingRepositoryImpl(database: database, writer: LocalMutationWriter())
        try await shopping.addEntry(NewShoppingEntry(item: .text("Huevos")))
        try await shopping.addEntry(NewShoppingEntry(item: .text("Pan")))

        #expect(await waitUntil { engine.callCount == 1 })
        try await Task.sleep(for: .milliseconds(100))
        #expect(engine.callCount == 1)
        #expect(await waitUntil { await scheduler.statusUpdates().first { _ in true }?.pendingChanges == 2 })
        await scheduler.stop()
    }

    @Test("Reconnecting syncs; changes reload widgets and schedule background refresh")
    func reconnectAndWidgets() async throws {
        let database = try await TestDatabase.make()
        let engine = CountingEngine(report: SyncReport(pulledCount: 1, changedCount: 1))
        let reachability = ControlledReachability()
        let reloader = CountingReloader()
        let scheduler = makeScheduler(
            engine: engine,
            database: database,
            reachability: reachability,
            reloader: reloader
        )
        await scheduler.start()

        reachability.continuation.yield(false)
        #expect(await waitUntil { await scheduler.statusUpdates().first { _ in true }?.isOnline == false })
        reachability.continuation.yield(true)

        #expect(await waitUntil { engine.callCount == 1 })
        #expect(await waitUntil { reloader.reloadCount == 1 && reloader.scheduleCount == 1 })
        await scheduler.stop()
    }

    @Test("Silent pushes report new data, and nothing syncs while signed out")
    func silentPushOutcome() async throws {
        let database = try await TestDatabase.make()
        let changed = makeScheduler(engine: CountingEngine(report: SyncReport(changedCount: 2)), database: database)
        #expect(await changed.syncNow(.silentPush) == .newData)

        let unchanged = makeScheduler(engine: CountingEngine(), database: database)
        #expect(await unchanged.syncNow(.silentPush) == .noData)

        let engine = CountingEngine()
        let signedOut = makeScheduler(engine: engine, database: database, signedIn: false)
        #expect(await signedOut.syncNow(.manual) == .skipped)
        #expect(engine.callCount == 0)
    }
}
