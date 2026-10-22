import SwiftUI

/// The returning-user sign-in. While locked it shows the login screen with a Face ID / Touch ID button on top
/// (prompted automatically) and the password form as the fallback; it is transparent while unlocked.
struct LockOverlay: View {
    @State private var viewModel: LockViewModel

    init(viewModel: LockViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            if viewModel.state != .unlocked {
                LoginView(
                    viewModel: Assembly.makeLoginViewModel(),
                    biometricUnlock: BiometricUnlock(
                        kind: viewModel.biometry,
                        isAuthenticating: viewModel.state == .authenticating
                    ) {
                        Task { await viewModel.send(.unlock) }
                    }
                )
                .transition(.opacity)
                .accessibilityAddTraits(.isModal)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
        .task { await viewModel.send(.appeared) }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Returning user · iPhone") {
        LockOverlay(viewModel: AuthPreviewFactory.makeLockViewModel(locked: true))
            .kodaPreview()
    }

    #Preview("Returning user · dark") {
        LockOverlay(viewModel: AuthPreviewFactory.makeLockViewModel(locked: true))
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Returning user · Mac", traits: .fixedLayout(width: 1000, height: 760)) {
        LockOverlay(viewModel: AuthPreviewFactory.makeLockViewModel(locked: true))
            .kodaPreview()
    }
#endif
