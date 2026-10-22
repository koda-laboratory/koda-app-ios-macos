import Foundation
import Observation

enum LockScreenState: Sendable, Equatable {
    case unlocked
    case locked
    case authenticating
}

enum LockIntent: Sendable {
    case appeared
    case unlock
}

/// Covers the UI while the biometric lock is engaged (the data stays readable for background sync).
@MainActor
@Observable
final class LockViewModel: MVIViewModel {
    // MARK: - Properties

    private(set) var state = LockScreenState.unlocked

    @ObservationIgnored private let observeLock: any ObserveAppLockUseCase
    @ObservationIgnored private let unlockApp: any UnlockAppUseCase
    @ObservationIgnored private let unlockReason: String
    @ObservationIgnored private var observation: Task<Void, Never>?

    // MARK: - Lifecycle

    init(observeLock: any ObserveAppLockUseCase, unlockApp: any UnlockAppUseCase, unlockReason: String) {
        self.observeLock = observeLock
        self.unlockApp = unlockApp
        self.unlockReason = unlockReason
    }

    deinit {
        observation?.cancel()
    }

    // MARK: - Intents

    func send(_ intent: LockIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        case .unlock:
            await unlock()
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observation == nil else { return }
        let observeLock = observeLock
        observation = Task { [weak self] in
            for await lockState in await observeLock.execute() {
                guard let self else { return }
                let wasUnlocked = self.state == .unlocked
                self.state = lockState == .locked ? .locked : .unlocked
                if wasUnlocked, lockState == .locked {
                    await self.unlock()
                }
            }
        }
    }

    private func unlock() async {
        guard state == .locked else { return }
        state = .authenticating
        let result = try? await unlockApp.execute(reason: unlockReason)
        state = result == .unlocked ? .unlocked : .locked
    }
}
