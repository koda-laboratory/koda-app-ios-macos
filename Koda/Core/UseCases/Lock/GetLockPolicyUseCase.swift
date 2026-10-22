/// The current biometric lock preferences (Profile).
protocol GetLockPolicyUseCase: Sendable {
    func execute() async -> BiometricLockPolicy
}

final class GetLockPolicyUseCaseImpl: GetLockPolicyUseCase, Sendable {
    private let lockService: any BiometricLockService

    init(lockService: any BiometricLockService) {
        self.lockService = lockService
    }

    func execute() async -> BiometricLockPolicy {
        await lockService.policy()
    }
}
