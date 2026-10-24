import SwiftUI

/// The entry point of the app, shared by iPhone and Mac.
@main
struct KodaApp: App {
    #if os(iOS)
        @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Siri, Shortcuts and Spotlight can launch the process cold and run an intent before any view appears.
        if !ProcessInfo.processInfo.skipsAppBootstrap {
            IntentServices.register()
        }
    }

    var body: some Scene {
        WindowGroup {
            if let coordinator = appDelegate.coordinator {
                KodaRootView(coordinator: coordinator)
            } else {
                // Previews and unit tests only need the process; skip the app bootstrap.
                EmptyView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            #if os(iOS)
                // The Mac reports activation through its app delegate instead.
                guard let coordinator = appDelegate.coordinator else { return }
                Task {
                    switch newPhase {
                    case .active: await coordinator.sceneDidBecomeActive()
                    case .background: await coordinator.sceneDidEnterBackground()
                    default: break
                    }
                }
            #endif
        }
        .commands {
            KodaCommands(coordinator: appDelegate.coordinator)
        }
        #if os(macOS)
            .defaultSize(width: 1280, height: 800)
        #endif

        #if os(macOS)
            Settings {
                if let coordinator = appDelegate.coordinator {
                    SettingsRootView(coordinator: coordinator)
                }
            }
        #endif
    }
}

/// Menu commands (Mac menu bar, and a hardware keyboard on iPhone): ⌘N new recipe, ⌘⇧L shopping list.
struct KodaCommands: Commands {
    let coordinator: AppLifecycleCoordinator?

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("command.new-recipe") {
                coordinator?.router.request(.newRecipe)
            }
            .keyboardShortcut("n")
            .disabled(!isSignedIn)

            Button("command.shopping-list") {
                coordinator?.router.selectedTab = .shopping
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .disabled(!isSignedIn)
        }
    }

    private var isSignedIn: Bool {
        if case .signedIn = coordinator?.sessionState { return true }
        return false
    }
}
