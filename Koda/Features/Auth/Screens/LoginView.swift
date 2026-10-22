import SwiftUI

/// Password login. Accounts are created at home (signup is disabled).
struct LoginView: View {
    @State private var viewModel: LoginViewModel
    @Environment(AppLifecycleCoordinator.self) private var coordinator: AppLifecycleCoordinator?
    @FocusState private var focusedField: FieldID?

    init(viewModel: LoginViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
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
                    Text("login.subtitle")
                        .font(KodaTypography.body)
                        .foregroundStyle(KodaColor.textSecondary)
                }

                LoginFormFields(viewModel: viewModel, focusedField: $focusedField)

                PrimaryButton("login.submit", isLoading: viewModel.state.isSubmitting) {
                    Task { await viewModel.send(.submit) }
                }
                .accessibilityIdentifier("login-submit")

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
        .ignoresSafeArea(edges: .top)
        .background(KodaColor.background)
        .dismissKeyboard()
        .toast($viewModel.toast)
        .onChange(of: viewModel.state) {
            guard case .completed(let userID) = viewModel.state else { return }
            Task { await coordinator?.didSignIn(userID: userID) }
        }
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
                SecureField("login.password.placeholder", text: $viewModel.form.password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused(focusedField, equals: .password)
                    .onSubmit { Task { await viewModel.send(.submit) } }
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
                .padding(.horizontal, KodaSpacing.m)
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
