import Foundation
import Testing

@testable import Koda

private actor StubLoginUseCase: LoginUseCase {
    var result: Result<HouseholdContext, KodaError>
    private(set) var calls: [(String, String)] = []

    init(result: Result<HouseholdContext, KodaError>) {
        self.result = result
    }

    func execute(email: String, password: String) async throws(KodaError) -> HouseholdContext {
        calls.append((email, password))
        return try result.get()
    }
}

private struct StreamLockUseCase: ObserveAppLockUseCase {
    let stream: AsyncStream<AppLockState>

    func execute() async -> AsyncStream<AppLockState> { stream }
}

private actor StubUnlockUseCase: UnlockAppUseCase {
    var result: AppLockState
    private(set) var count = 0

    init(result: AppLockState) {
        self.result = result
    }

    func execute(reason: String) async throws(KodaError) -> AppLockState {
        count += 1
        return result
    }
}

private let context = HouseholdContext(
    userID: UUID(uuidString: TestDatabase.userID) ?? UUID(),
    displayName: "Test",
    avatarEmoji: nil,
    household: Household(id: UUID(), name: "Casa", timeZone: .gmt, role: .owner, members: [])
)

@MainActor
@Suite("Login and lock")
struct AuthViewModelTests {
    @Test("Invalid form shows inline errors and does not call the use case")
    func invalidForm() async {
        let login = StubLoginUseCase(result: .success(context))
        let viewModel = LoginViewModel(login: login)
        viewModel.form.email = "no-arroba"
        await viewModel.send(.submit)
        #expect(viewModel.state == .invalidForm)
        #expect(viewModel.showsEmailError)
        #expect(viewModel.showsPasswordError)
        #expect(await login.calls.isEmpty)
    }

    @Test("A successful login normalizes the email, clears the password and completes")
    func success() async {
        let login = StubLoginUseCase(result: .success(context))
        let viewModel = LoginViewModel(login: login)
        viewModel.form = LoginFormState(email: "  Casa@Example.com ", password: "secret")
        await viewModel.send(.submit)
        #expect(viewModel.state == .completed(userID: TestDatabase.userID))
        #expect(viewModel.form.password.isEmpty)
        #expect(await login.calls.first?.0 == "casa@example.com")
    }

    @Test("Rejected credentials stay inline; network errors become a toast")
    func failures() async {
        let rejected = KodaError(type: .badRequest, reason: "x", rawCode: KodaErrorCode.invalidCredentials.rawValue)
        let viewModel = LoginViewModel(login: StubLoginUseCase(result: .failure(rejected)))
        viewModel.form = LoginFormState(email: "a@b.es", password: "x")
        await viewModel.send(.submit)
        #expect(viewModel.state == .failed(messageKey: "error.code.invalid-credentials"))
        await viewModel.send(.editedField)
        #expect(viewModel.state == .idle)

        let offline = LoginViewModel(
            login: StubLoginUseCase(result: .failure(KodaError(type: .noInternet, reason: "x")))
        )
        offline.form = LoginFormState(email: "a@b.es", password: "x")
        await offline.send(.submit)
        #expect(offline.state == .idle)
        #expect(offline.toast?.messageKey == "error.type.no-internet")
    }

    @Test("A lock asks for authentication automatically and unlocks on success")
    func lock() async {
        let (stream, continuation) = AsyncStream<AppLockState>.makeStream()
        let unlock = StubUnlockUseCase(result: .unlocked)
        let viewModel = LockViewModel(
            observeLock: StreamLockUseCase(stream: stream),
            unlockApp: unlock,
            unlockReason: "Test"
        )
        await viewModel.send(.appeared)
        continuation.yield(.locked)
        #expect(await waitUntil { await unlock.count == 1 })
        #expect(await eventually { viewModel.state == .unlocked })
    }

    @Test("A failed authentication keeps the lock and the button retries")
    func lockFailure() async {
        let (stream, continuation) = AsyncStream<AppLockState>.makeStream()
        let unlock = StubUnlockUseCase(result: .locked)
        let viewModel = LockViewModel(
            observeLock: StreamLockUseCase(stream: stream),
            unlockApp: unlock,
            unlockReason: "Test"
        )
        await viewModel.send(.appeared)
        continuation.yield(.locked)
        #expect(await waitUntil { await unlock.count == 1 })
        #expect(await eventually { viewModel.state == .locked })
        await viewModel.send(.unlock)
        #expect(await unlock.count == 2)
    }
}
