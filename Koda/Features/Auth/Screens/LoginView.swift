import SwiftUI

/// The Face ID / Touch ID entry offered to a returning user on top of the password form.
struct BiometricUnlock {
    let kind: BiometryKind
    let isAuthenticating: Bool
    let action: () -> Void

    var titleKey: LocalizedStringKey {
        switch kind {
        case .touchID: "unlock.touch-id"
        case .opticID: "unlock.optic-id"
        case .faceID, .none: "unlock.face-id"
        }
    }

    var systemImage: String {
        switch kind {
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .faceID, .none: "faceid"
        }
    }
}

/// Password login. Accounts are created at home (signup is disabled). A returning user also gets the Face ID /
/// Touch ID button (`biometricUnlock`), so there is a single sign-in step.
struct LoginView: View {
    @State private var viewModel: LoginViewModel
    @Environment(AppLifecycleCoordinator.self) private var coordinator: AppLifecycleCoordinator?
    @FocusState private var focusedField: FieldID?
    private let biometricUnlock: BiometricUnlock?

    init(viewModel: LoginViewModel, biometricUnlock: BiometricUnlock? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.biometricUnlock = biometricUnlock
    }

    /// The biometric button only exists when the device has enrolled biometrics.
    private var availableBiometricUnlock: BiometricUnlock? {
        guard let biometricUnlock, biometricUnlock.kind != .none else { return nil }
        return biometricUnlock
    }

    var body: some View {
        content
            .ignoresSafeArea(edges: .top)
            .background(KodaColor.background)
            .dismissKeyboard()
            .toast($viewModel.toast)
            .onChange(of: viewModel.state) {
                guard case .completed(let userID) = viewModel.state else { return }
                Task { await coordinator?.didSignIn(userID: userID) }
            }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KodaSpacing.l) {
                LoginArcsHeader()
                    .padding(.horizontal, KodaSpacing.l + KodaSpacing.xxs)
                    .frame(maxWidth: KodaSize.loginArcsWidth)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: KodaSpacing.xs - 2) {
                    Text("login.title")
                        .font(KodaTypography.hero)
                        .foregroundStyle(KodaColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(availableBiometricUnlock == nil ? "login.subtitle" : "unlock.subtitle")
                        .font(KodaTypography.body)
                        .foregroundStyle(KodaColor.textSecondary)
                }

                if let biometric = availableBiometricUnlock {
                    PrimaryButton(
                        biometric.titleKey,
                        systemImage: biometric.systemImage,
                        isLoading: biometric.isAuthenticating,
                        action: biometric.action
                    )
                    .accessibilityIdentifier("login-biometric")

                    Text("unlock.or-password")
                        .font(KodaTypography.footnote.weight(.semibold))
                        .foregroundStyle(KodaColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                LoginFormFields(viewModel: viewModel, focusedField: $focusedField)

                if availableBiometricUnlock == nil {
                    PrimaryButton("login.submit", isLoading: viewModel.state.isSubmitting) {
                        Task { await viewModel.send(.submit) }
                    }
                    .accessibilityIdentifier("login-submit")
                } else {
                    Button {
                        Task { await viewModel.send(.submit) }
                    } label: {
                        Text("login.submit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.kodaPill(.outline))
                    .disabled(viewModel.state.isSubmitting)
                    .accessibilityIdentifier("login-submit")
                }

                Text("login.private-note")
                    .font(KodaTypography.footnote)
                    .foregroundStyle(KodaColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, KodaSpacing.l + KodaSpacing.xxs)
            .padding(.bottom, KodaSpacing.xl)
            .frame(maxWidth: KodaSize.formWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .keyboardMargin()
    }
}

/// Email and password with inline validation and the sign-in error.
private struct LoginFormFields: View {
    @Bindable var viewModel: LoginViewModel
    var focusedField: FocusState<LoginView.FieldID?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            LabeledField(labelKey: "login.email", errorKey: viewModel.showsEmailError ? "login.email.invalid" : nil) {
                TextField("login.email.placeholder", text: $viewModel.form.email)
                    .platformEmailField()
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused(focusedField, equals: .email)
                    .onSubmit { focusedField.wrappedValue = .password }
                    .accessibilityIdentifier("login-email")
            }
            LabeledField(
                labelKey: "login.password",
                errorKey: viewModel.showsPasswordError ? "login.password.missing" : nil
            ) {
                PasswordField(
                    placeholderKey: "login.password.placeholder",
                    text: $viewModel.form.password,
                    focus: focusedField,
                    field: .password
                ) {
                    Task { await viewModel.send(.submit) }
                }
                .submitLabel(.go)
                .accessibilityIdentifier("login-password")
            }
            if case .failed(let messageKey) = viewModel.state {
                Label(LocalizedStringKey(messageKey), systemImage: "exclamationmark.circle")
                    .font(KodaTypography.footnote)
                    .foregroundStyle(KodaColor.error)
                    .accessibilityIdentifier("login-error")
            }
        }
        .onChange(of: viewModel.form) {
            Task { await viewModel.send(.editedField) }
        }
    }
}

extension LoginView {
    enum FieldID: Hashable {
        case email
        case password
    }
}

/// A labelled input box of the login form.
private struct LabeledField<Field: View>: View {
    let labelKey: LocalizedStringKey
    let errorKey: LocalizedStringKey?
    @ViewBuilder let field: () -> Field

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.xs - 2) {
            Text(labelKey)
                .font(KodaTypography.footnote.weight(.semibold))
                .foregroundStyle(KodaColor.textSecondary)
            field()
                .textFieldStyle(.plain)
                .font(KodaTypography.body.weight(.medium))
                .padding(.leading, KodaSpacing.m)
                .padding(.trailing, KodaSpacing.xs)
                .frame(minHeight: KodaSize.fieldHeight)
                .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaSpacing.m, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: KodaSpacing.m, style: .continuous)
                        .strokeBorder(errorKey == nil ? KodaColor.brand.opacity(0.14) : KodaColor.error)
                }
            if let errorKey {
                Text(errorKey)
                    .font(KodaTypography.caption)
                    .foregroundStyle(KodaColor.error)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Login · iPhone") {
        LoginView(viewModel: AuthPreviewFactory.makeLoginViewModel())
            .kodaPreview()
    }

    #Preview("Login · error") {
        LoginView(viewModel: AuthPreviewFactory.makeLoginViewModel(failing: true))
            .kodaPreview()
    }

    #Preview("Login · dark") {
        LoginView(viewModel: AuthPreviewFactory.makeLoginViewModel())
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Login · Mac", traits: .fixedLayout(width: 1000, height: 760)) {
        LoginView(viewModel: AuthPreviewFactory.makeLoginViewModel())
            .kodaPreview()
    }
#endif
