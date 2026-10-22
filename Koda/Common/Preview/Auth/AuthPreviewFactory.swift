import Foundation

/// Deterministic auth fakes for previews (no network, no Keychain, no biometrics).
@MainActor
enum AuthPreviewFactory {
    static func makeLoginViewModel(failing: Bool = false) -> LoginViewModel {
        let viewModel = LoginViewModel(login: PreviewLoginUseCase(fails: failing))
        viewModel.form.email = "casa@example.com"
        if failing {
            viewModel.form.password = "x"
            Task { await viewModel.send(.submit) }
        }
        return viewModel
    }

    static func makeLockViewModel(locked: Bool) -> LockViewModel {
        LockViewModel(
            observeLock: PreviewObserveAppLockUseCase(state: locked ? .locked : .unlocked),
            unlockApp: PreviewUnlockAppUseCase(),
            unlockReason: "Preview"
        )
    }
}

private struct PreviewLoginUseCase: LoginUseCase {
    let fails: Bool

    func execute(email: String, password: String) async throws(KodaError) -> HouseholdContext {
        if fails {
            throw KodaError(type: .badRequest, reason: "Preview", rawCode: KodaErrorCode.invalidCredentials.rawValue)
        }
        return PreviewHousehold.context
    }
}

private struct PreviewObserveAppLockUseCase: ObserveAppLockUseCase {
    let state: AppLockState

    func execute() async -> AsyncStream<AppLockState> {
        AsyncStream { $0.yield(state) }
    }
}

private struct PreviewUnlockAppUseCase: UnlockAppUseCase {
    func execute(reason: String) async throws(KodaError) -> AppLockState { .locked }

    func biometry() async -> BiometryKind { .faceID }
}

/// The sample household used by every preview.
enum PreviewHousehold {
    static let householdID = UUID(uuidString: "11111111-1111-4111-8111-111111111111") ?? UUID()
    static let userID = UUID(uuidString: "22222222-2222-4222-8222-222222222222") ?? UUID()
    static let partnerID = UUID(uuidString: "33333333-3333-4333-8333-333333333333") ?? UUID()

    static let context = HouseholdContext(
        userID: userID,
        displayName: "Manu",
        avatarEmoji: nil,
        household: Household(
            id: householdID,
            name: "Casa",
            timeZone: .household,
            role: .owner,
            members: [
                HouseholdMember(userID: userID, role: .owner, displayName: "Manu", avatarEmoji: nil),
                HouseholdMember(userID: partnerID, role: .member, displayName: "Olga", avatarEmoji: "🍋"),
            ]
        )
    )
}
