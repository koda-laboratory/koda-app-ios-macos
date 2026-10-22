import Foundation
import Synchronization
import Testing

@testable import Koda

@Suite("Biometric lock policy")
struct BiometricLockServiceTests {
    private final class FakeAuthenticator: BiometricAuthenticating {
        let available: Bool
        let result: Result<Bool, URLError>

        init(available: Bool = true, result: Result<Bool, URLError> = .success(true)) {
            self.available = available
            self.result = result
        }

        func canAuthenticate() -> Bool { available }

        func authenticate(reason: String) async throws -> Bool { try result.get() }
    }

    private final class MemoryPreferences: LockPreferencesDataSource {
        private let stored = Mutex(BiometricLockPolicy.default)

        func policy() -> BiometricLockPolicy { stored.withLock { $0 } }

        func save(_ policy: BiometricLockPolicy) { stored.withLock { $0 = policy } }
    }

    private final class ManualClock: Sendable {
        private let current = Mutex(Date(timeIntervalSince1970: 1_792_663_200))

        func now() -> Date { current.withLock { $0 } }

        func advance(_ seconds: TimeInterval) { current.withLock { $0 = $0.addingTimeInterval(seconds) } }
    }

    private func makeService(
        authenticator: FakeAuthenticator = FakeAuthenticator(),
        preferences: MemoryPreferences = MemoryPreferences(),
        clock: ManualClock = ManualClock()
    ) -> BiometricLockServiceImpl {
        BiometricLockServiceImpl(authenticator: authenticator, preferences: preferences, clock: clock.now)
    }

    @Test("Cold start locks when enabled and unlocking succeeds")
    func coldStartLocks() async throws {
        let service = makeService()
        #expect(await service.applicationDidLaunch() == .locked)
        #expect(try await service.unlock(reason: "Desbloquear Koda") == .unlocked)
    }

    @Test(
        "Returning from background locks only after the timeout",
        arguments: [(60.0, AppLockState.unlocked), (299.0, .unlocked), (301.0, .locked)]
    )
    func backgroundTimeout(seconds: TimeInterval, expected: AppLockState) async {
        let clock = ManualClock()
        let service = makeService(clock: clock)
        await service.applicationDidLaunch()
        _ = try? await service.unlock(reason: "test")

        await service.applicationDidEnterBackground()
        clock.advance(seconds)

        #expect(await service.applicationWillEnterForeground() == expected)
    }

    @Test("A disabled policy or a device without authentication never locks")
    func neverLocksWhenUnavailable() async {
        let preferences = MemoryPreferences()
        preferences.save(BiometricLockPolicy(isEnabled: false, backgroundTimeout: 300))
        #expect(await makeService(preferences: preferences).applicationDidLaunch() == .unlocked)
        #expect(
            await makeService(authenticator: FakeAuthenticator(available: false)).applicationDidLaunch() == .unlocked
        )
    }

    @Test("A failed or cancelled authentication keeps the app locked")
    func failedAuthenticationStaysLocked() async throws {
        let rejected = makeService(authenticator: FakeAuthenticator(result: .success(false)))
        await rejected.applicationDidLaunch()
        #expect(try await rejected.unlock(reason: "test") == .locked)

        let failing = makeService(authenticator: FakeAuthenticator(result: .failure(URLError(.cancelled))))
        await failing.applicationDidLaunch()
        await #expect(throws: KodaError.self) { try await failing.unlock(reason: "test") }
        #expect(await failing.state() == .locked)
    }

    @Test("A password login never asks for biometrics on top of it")
    func passwordLoginUnlocks() async {
        let service = makeService()
        await service.applicationDidLaunch()
        #expect(await service.state() == .locked)
        await service.markUnlocked()
        #expect(await service.state() == .unlocked)
    }

    @Test("Without enrolled biometrics the app opens directly, never with the device passcode")
    func noBiometricsOpensDirectly() async throws {
        let service = makeService(authenticator: FakeAuthenticator(available: false))
        #expect(await service.applicationDidLaunch() == .unlocked)
        #expect(await service.biometry() == .none)
        #expect(try await service.unlock(reason: "test") == .unlocked)
    }

    @Test("Disabling the policy and logging out unlock immediately")
    func disablingUnlocks() async {
        let service = makeService()
        await service.applicationDidLaunch()
        await service.updatePolicy(BiometricLockPolicy(isEnabled: false, backgroundTimeout: 300))
        #expect(await service.state() == .unlocked)

        let other = makeService()
        await other.applicationDidLaunch()
        await other.reset()
        #expect(await other.state() == .unlocked)
    }
}
