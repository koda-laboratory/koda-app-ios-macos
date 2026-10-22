/// Signs out: tries to push the pending outbox first (best effort, bounded by `pushTimeout`), stops sync, removes this device from push (`DELETE /devices/:id`), revokes the session on the
/// server, and clears the Keychain session **and** the local database. Remote steps are best effort so logout
/// also works offline.
protocol LogoutUseCase: Sendable {
    func execute() async throws(KodaError)
}

final class LogoutUseCaseImpl: LogoutUseCase, Sendable {
    // MARK: - Properties

    private let syncScheduler: any SyncScheduling
    private let deviceRepository: any DeviceRepository
    private let authRepository: any AuthRepository
    private let sessionService: any SessionService
    private let localDataRepository: any LocalDataRepository
    private let lockService: (any BiometricLockService)?
    private let pushTimeout: Duration

    // MARK: - Lifecycle

    init(
        syncScheduler: any SyncScheduling,
        deviceRepository: any DeviceRepository,
        authRepository: any AuthRepository,
        sessionService: any SessionService,
        localDataRepository: any LocalDataRepository,
        lockService: (any BiometricLockService)? = nil
    ) {
        self.syncScheduler = syncScheduler
        self.deviceRepository = deviceRepository
        self.authRepository = authRepository
        self.sessionService = sessionService
        self.localDataRepository = localDataRepository
        self.lockService = lockService
        self.pushTimeout = .seconds(5)
    }

    // MARK: - Public Methods

    func execute() async throws(KodaError) {
        await pushPendingChanges()
        await syncScheduler.stop()
        // Both calls need the current access token, so they run before the session is deleted.
        try? await deviceRepository.unregister()
        try? await authRepository.signOut()
        try await sessionService.delete()
        try await localDataRepository.eraseAll()
        await lockService?.reset()
    }

    // MARK: - Private Methods

    /// Gives the outbox a last chance to reach the server; whatever is still pending afterwards is lost.
    private func pushPendingChanges() async {
        let syncScheduler = syncScheduler
        let timeout = pushTimeout
        // Unstructured on purpose: a sync that ignores cancellation must not hold the logout past the timeout.
        let (finished, continuation) = AsyncStream<Void>.makeStream()
        let sync = Task {
            _ = await syncScheduler.syncNow(.manual)
            continuation.yield()
        }
        let timer = Task {
            try? await Task.sleep(for: timeout)
            continuation.yield()
        }
        for await _ in finished { break }
        continuation.finish()
        sync.cancel()
        timer.cancel()
    }
}
