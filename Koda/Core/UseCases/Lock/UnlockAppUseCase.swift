/// Signs a returning user in with Face ID / Touch ID.
protocol UnlockAppUseCase: Sendable {
    @discardableResult
    func execute(reason: String) async throws(KodaError) -> AppLockState
    /// Biometrics offered by the device, to label the button.
    func biometry() async -> BiometryKind
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

    func biometry() async -> BiometryKind {
        await lockService.biometry()
    }
}
