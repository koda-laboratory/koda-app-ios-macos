/// Whether the UI must be covered by the lock screen.
protocol ObserveAppLockUseCase: Sendable {
    func execute() async -> AsyncStream<AppLockState>
}

final class ObserveAppLockUseCaseImpl: ObserveAppLockUseCase, Sendable {
    private let lockService: any BiometricLockService

    init(lockService: any BiometricLockService) {
        self.lockService = lockService
    }

    func execute() async -> AsyncStream<AppLockState> {
        await lockService.stateUpdates()
    }
}
