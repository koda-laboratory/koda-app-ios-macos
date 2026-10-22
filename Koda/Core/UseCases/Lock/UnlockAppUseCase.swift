/// Unlocks the UI with device-owner authentication.
protocol UnlockAppUseCase: Sendable {
    @discardableResult
    func execute(reason: String) async throws(KodaError) -> AppLockState
}

final class UnlockAppUseCaseImpl: UnlockAppUseCase, Sendable {
    private let lockService: any BiometricLockService

    init(lockService: any BiometricLockService) {
        self.lockService = lockService
    }

    @discardableResult
    func execute(reason: String) async throws(KodaError) -> AppLockState {
        try await lockService.unlock(reason: reason)
    }
}
