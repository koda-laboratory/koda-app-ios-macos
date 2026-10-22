/// Handles a forced login (`invalid_grant` or an equivalent rejected refresh): stops sync and forgets the
/// unusable Keychain session, but keeps the local database and the outbox so pending changes sync after the
/// next login.
protocol ExpireSessionUseCase: Sendable {
    func execute() async
}

final class ExpireSessionUseCaseImpl: ExpireSessionUseCase, Sendable {
    private let syncScheduler: any SyncScheduling
    private let sessionService: any SessionService

    init(syncScheduler: any SyncScheduling, sessionService: any SessionService) {
        self.syncScheduler = syncScheduler
        self.sessionService = sessionService
    }

    func execute() async {
        await syncScheduler.stop()
        try? await sessionService.delete()
    }
}
