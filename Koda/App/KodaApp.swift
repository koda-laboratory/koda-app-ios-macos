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

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.skipsAppBootstrap {
                // Previews and unit tests only need the process; skip the app bootstrap.
                EmptyView()
            } else {
                KodaRootView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard !ProcessInfo.processInfo.skipsAppBootstrap else { return }
            let loggerService = DependencyContainer.shared.required(LoggerService.self)
            loggerService.debug("scenePhase \(String(describing: newPhase))")
            // Phase 2: trigger SyncEngine on `.active` (local-first rule).
        }

        #if os(macOS)
            Settings {
                ContentUnavailableView("common.coming-soon", systemImage: "person.crop.circle")
                    .frame(width: 420, height: 280)
            }
        #endif
    }
}

/// The top-level view. Temporary: shows the design system until the tab root of Phase 3 exists.
struct KodaRootView: View {
    @State private var appRouter = AppRouter()

    var body: some View {
        AppTabNavigationStack(tab: .today) {
            ThemeShowcaseView()
        }
        .environment(appRouter)
        .tint(KodaColor.brand)
    }
}
