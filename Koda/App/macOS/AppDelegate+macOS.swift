#if os(macOS)
    import AppKit

    @MainActor
    final class AppDelegate: NSObject, NSApplicationDelegate {
        /// Created on launch unless the process only hosts tests or previews.
        private(set) var coordinator: AppLifecycleCoordinator?

        private var loggerService: any LoggerService {
            DependencyContainer.shared.required(LoggerService.self)
        }

        func applicationDidFinishLaunching(_ notification: Notification) {
            guard !ProcessInfo.processInfo.skipsAppBootstrap else { return }
            loggerService.debug("didFinishLaunching (macOS)")

            let coordinator = Assembly.makeAppLifecycleCoordinator()
            self.coordinator = coordinator
            Task { await coordinator.applicationDidFinishLaunching() }
        }

        /// The Mac has no background refresh task: it syncs whenever the app becomes active.
        func applicationDidBecomeActive(_ notification: Notification) {
            guard let coordinator else { return }
            Task { await coordinator.sceneDidBecomeActive() }
        }

        func applicationDidResignActive(_ notification: Notification) {
            guard let coordinator else { return }
            Task { await coordinator.sceneDidEnterBackground() }
        }

        // MARK: - Remote notifications

        func application(
            _ application: NSApplication,
            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
        ) {
            // Never log the token itself.
            loggerService.info("Registered for remote notifications (\(deviceToken.count) bytes).")
            guard let coordinator else { return }
            Task { await coordinator.didRegisterForRemoteNotifications(deviceToken: deviceToken) }
        }

        func application(
            _ application: NSApplication,
            didFailToRegisterForRemoteNotificationsWithError error: any Error
        ) {
            loggerService.warning("Remote notification registration failed: \(error.localizedDescription)")
        }

        /// Silent push while the app runs → sync. A closed Mac app syncs on its next activation.
        func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
            guard let coordinator else { return }
            loggerService.debug("Silent push received.")
            Task { await coordinator.handleSilentPush() }
        }
    }
#endif
