/// Signs out: stops sync, removes this device from push (`DELETE /devices/:id`), revokes the session on the
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

    // MARK: - Lifecycle

    init(
        syncScheduler: any SyncScheduling,
        deviceRepository: any DeviceRepository,
        authRepository: any AuthRepository,
        sessionService: any SessionService,
        localDataRepository: any LocalDataRepository
    ) {
        self.syncScheduler = syncScheduler
        self.deviceRepository = deviceRepository
        self.authRepository = authRepository
        self.sessionService = sessionService
        self.localDataRepository = localDataRepository
    }

    // MARK: - Public Methods

    func execute() async throws(KodaError) {
        await syncScheduler.stop()
        // Both calls need the current access token, so they run before the session is deleted.
        try? await deviceRepository.unregister()
        try? await authRepository.signOut()
        try await sessionService.delete()
        try await localDataRepository.eraseAll()
    }
}
