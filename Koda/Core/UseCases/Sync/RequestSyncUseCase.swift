/// Manual sync (pull-to-refresh, the Profile "sync now" action). Local data stays usable whatever the outcome.
protocol RequestSyncUseCase: Sendable {
    @discardableResult
    func execute() async -> SyncOutcome
}

final class RequestSyncUseCaseImpl: RequestSyncUseCase, Sendable {
    private let syncScheduler: any SyncScheduling

    init(syncScheduler: any SyncScheduling) {
        self.syncScheduler = syncScheduler
    }

    @discardableResult
    func execute() async -> SyncOutcome {
        await syncScheduler.syncNow(.manual)
    }
}
