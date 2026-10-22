/// Changes the biometric lock preferences (Profile).
protocol UpdateLockPolicyUseCase: Sendable {
    func execute(_ policy: BiometricLockPolicy) async
}

final class UpdateLockPolicyUseCaseImpl: UpdateLockPolicyUseCase, Sendable {
    private let lockService: any BiometricLockService

    init(lockService: any BiometricLockService) {
        self.lockService = lockService
    }

    func execute(_ policy: BiometricLockPolicy) async {
        await lockService.updatePolicy(policy)
    }
}
