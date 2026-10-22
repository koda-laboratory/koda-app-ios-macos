import Foundation

/// Biometric lock of the UI (never of the data: tokens and the database stay readable after first unlock so
/// background sync, silent pushes and intents keep working).
///
/// Policy: lock on cold start and when returning after more than `backgroundTimeout` (5 min by default) in the
/// background, if enabled and the device can authenticate the owner.
protocol BiometricLockService: Sendable {
    func state() async -> AppLockState
    func stateUpdates() async -> AsyncStream<AppLockState>
    func policy() async -> BiometricLockPolicy
    func updatePolicy(_ policy: BiometricLockPolicy) async
    /// Cold start: locks when the policy is enabled.
    @discardableResult
    func applicationDidLaunch() async -> AppLockState
    func applicationDidEnterBackground() async
    /// Locks again when the app stayed in the background longer than the timeout.
    @discardableResult
    func applicationWillEnterForeground() async -> AppLockState
    /// Runs device-owner authentication (Face ID / Touch ID / passcode / Mac password).
    @discardableResult
    func unlock(reason: String) async throws(KodaError) -> AppLockState
    /// Logout: nothing left to protect.
    func reset() async
}

actor BiometricLockServiceImpl: BiometricLockService {
    // MARK: - Properties

    private let authenticator: any BiometricAuthenticating
    private let preferences: any LockPreferencesDataSource
    private let clock: @Sendable () -> Date

    private var currentState = AppLockState.unlocked
    private var enteredBackgroundAt: Date?
    private var continuations: [UUID: AsyncStream<AppLockState>.Continuation] = [:]

    // MARK: - Lifecycle

    init(
        authenticator: any BiometricAuthenticating,
        preferences: any LockPreferencesDataSource,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.authenticator = authenticator
        self.preferences = preferences
        self.clock = clock
    }

    // MARK: - Public Methods

    func state() -> AppLockState {
        currentState
    }

    func stateUpdates() -> AsyncStream<AppLockState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AppLockState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuations[id] = continuation
        continuation.yield(currentState)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    func policy() -> BiometricLockPolicy {
        preferences.policy()
    }

    func updatePolicy(_ policy: BiometricLockPolicy) {
        preferences.save(policy)
        if !policy.isEnabled {
            transition(to: .unlocked)
        }
    }

    @discardableResult
    func applicationDidLaunch() -> AppLockState {
        enteredBackgroundAt = nil
        transition(to: canLock ? .locked : .unlocked)
        return currentState
    }

    func applicationDidEnterBackground() {
        enteredBackgroundAt = clock()
    }

    @discardableResult
    func applicationWillEnterForeground() -> AppLockState {
        defer { enteredBackgroundAt = nil }
        guard let enteredBackgroundAt, canLock else { return currentState }
        if clock().timeIntervalSince(enteredBackgroundAt) > preferences.policy().backgroundTimeout {
            transition(to: .locked)
        }
        return currentState
    }

    @discardableResult
    func unlock(reason: String) async throws(KodaError) -> AppLockState {
        guard currentState == .locked else { return currentState }
        guard authenticator.canAuthenticate() else {
            // Biometrics and passcode were removed: locking would leave the user stuck.
            transition(to: .unlocked)
            return currentState
        }
        do {
            if try await authenticator.authenticate(reason: reason) {
                transition(to: .unlocked)
            }
        } catch {
            throw KodaError(type: .auth, reason: "Device owner authentication failed: \(error.localizedDescription)")
        }
        return currentState
    }

    func reset() {
        enteredBackgroundAt = nil
        transition(to: .unlocked)
    }

    // MARK: - Private Methods

    private var canLock: Bool {
        preferences.policy().isEnabled && authenticator.canAuthenticate()
    }

    private func transition(to newState: AppLockState) {
        guard newState != currentState else { return }
        currentState = newState
        for continuation in continuations.values {
            continuation.yield(newState)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
