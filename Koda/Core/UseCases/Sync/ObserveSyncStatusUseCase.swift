/// Online state and pending changes for the shared offline indicator.
protocol ObserveSyncStatusUseCase: Sendable {
    func execute() async -> AsyncStream<SyncStatus>
}

final class ObserveSyncStatusUseCaseImpl: ObserveSyncStatusUseCase, Sendable {
    private let syncScheduler: any SyncScheduling

    init(syncScheduler: any SyncScheduling) {
        self.syncScheduler = syncScheduler
    }

    func execute() async -> AsyncStream<SyncStatus> {
        await syncScheduler.statusUpdates()
    }
}
