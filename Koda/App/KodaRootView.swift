import SwiftUI

/// Switches between launch, login and the signed-in app, and covers the UI with the biometric lock.
struct KodaRootView: View {
    let coordinator: AppLifecycleCoordinator

    var body: some View {
        ZStack {
            switch coordinator.sessionState {
            case .restoring:
                SplashView()
            case .signedOut:
                LoginView(viewModel: Assembly.makeLoginViewModel())
                    .transition(.opacity)
            case .signedIn(let userID):
                MainTabView(viewModel: Assembly.makeShellViewModel())
                    .id(userID)
                    .overlay {
                        LockOverlay(viewModel: Assembly.makeLockViewModel())
                    }
            }
        }
        .environment(coordinator)
        .environment(coordinator.router)
        .tint(KodaColor.brandText)
        .kodaAppearance()
        .onOpenURL { coordinator.open(url: $0) }
    }
}

/// Launch placeholder while the session is restored from the Keychain (no network).
struct SplashView: View {
    var body: some View {
        VStack {
            KodaArcs()
                .frame(width: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KodaColor.background)
    }
}

#if os(macOS)
    /// The Mac `Settings` scene (⌘,): Profile, once signed in.
    struct SettingsRootView: View {
        let coordinator: AppLifecycleCoordinator

        var body: some View {
            Group {
                if case .signedIn = coordinator.sessionState {
                    ProfileView(viewModel: Assembly.makeProfileViewModel(), presentation: .settings)
                } else {
                    ContentUnavailableView("profile.signed-out", systemImage: "person.crop.circle")
                }
            }
            .frame(minWidth: 520, idealWidth: 560, minHeight: 560, idealHeight: 680)
            .environment(coordinator)
            .environment(coordinator.router)
            .tint(KodaColor.brandText)
            .kodaAppearance()
        }
    }
#endif

// MARK: - Previews

#if DEBUG
    #Preview("Splash") {
        SplashView()
    }

    #Preview("Splash · dark") {
        SplashView().preferredColorScheme(.dark)
    }

    #Preview("Splash · Mac", traits: .fixedLayout(width: 1000, height: 700)) {
        SplashView()
    }
#endif
