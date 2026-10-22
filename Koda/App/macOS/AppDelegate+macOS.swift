#if os(macOS)
    import AppKit

    @MainActor
    final class AppDelegate: NSObject, NSApplicationDelegate {
        private var loggerService: any LoggerService {
            DependencyContainer.shared.required(LoggerService.self)
        }

        func applicationDidFinishLaunching(_ notification: Notification) {
            guard !ProcessInfo.processInfo.skipsAppBootstrap else { return }
            loggerService.debug("didFinishLaunching (macOS)")
            // After login: `PlatformRemoteNotifications.register()` (Phase 4).
        }

        // MARK: - Remote notifications

        func application(
            _ application: NSApplication,
            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
        ) {
            // Never log the token itself. Phase 4: send it with `PUT /devices`.
            loggerService.info("Registered for remote notifications (\(deviceToken.count) bytes).")
        }

        func application(
            _ application: NSApplication,
            didFailToRegisterForRemoteNotificationsWithError error: any Error
        ) {
            loggerService.warning("Remote notification registration failed: \(error.localizedDescription)")
        }

        func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
            // Phase 4: silent push → SyncEngine pull. If the app is closed it syncs on the next launch.
            loggerService.debug("Silent push received.")
        }
    }
#endif
