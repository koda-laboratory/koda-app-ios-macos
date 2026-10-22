import Foundation
import Observation

enum LoginState: Sendable, Equatable {
    case idle
    case invalidForm
    case submitting
    /// A rejected sign-in with a message shown under the form (string-catalog key).
    case failed(messageKey: String)
    case completed(userID: String)

    var isSubmitting: Bool { self == .submitting }
}

enum LoginIntent: Sendable {
    case submit
    case editedField
}

/// Password login (GoTrue password grant through `LoginUseCase`).
@MainActor
@Observable
final class LoginViewModel: FormViewModel {
    // MARK: - Properties

    private(set) var state = LoginState.idle
    var form = LoginFormState()
    var toast: Toast?

    @ObservationIgnored private let login: any LoginUseCase

    // MARK: - Lifecycle

    init(login: any LoginUseCase) {
        self.login = login
    }

    // MARK: - Derived

    var showsEmailError: Bool { state == .invalidForm && !form.isEmailValid }
    var showsPasswordError: Bool { state == .invalidForm && form.password.isEmpty }

    // MARK: - Intents

    func send(_ intent: LoginIntent) async {
        switch intent {
        case .submit:
            await submit()
        case .editedField:
            if case .failed = state { state = .idle }
            if state == .invalidForm, form.isValid { state = .idle }
        }
    }

    // MARK: - Private Methods

    private func submit() async {
        guard !state.isSubmitting else { return }
        guard form.isValid else {
            state = .invalidForm
            return
        }
        state = .submitting
        do {
            let context = try await login.execute(email: form.normalizedEmail, password: form.password)
            form.password = ""
            state = .completed(userID: context.userID.uuidString.lowercased())
        } catch {
            if error.type == .auth || error.type == .badRequest || error.code == .invalidCredentials {
                state = .failed(messageKey: error.localizedPresentationKey)
            } else {
                state = .idle
                toast = .error(error)
            }
        }
    }
}
