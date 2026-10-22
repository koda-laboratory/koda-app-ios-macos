#if os(iOS)
    import UIKit

    @MainActor
    final class AppDelegate: NSObject, UIApplicationDelegate {
        private var loggerService: any LoggerService {
            DependencyContainer.shared.required(LoggerService.self)
        }

        func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
        ) -> Bool {
            guard !ProcessInfo.processInfo.skipsAppBootstrap else { return true }
            loggerService.debug("didFinishLaunching (iOS)")
            // Phase 2/4: register the BGAppRefreshTask (`AppEnvironment.backgroundSyncTaskIdentifier`) and,
            // after login, `PlatformRemoteNotifications.register()`.
            return true
        }

        // MARK: - Remote notifications

        func application(
            _ application: UIApplication,
            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
        ) {
            // Never log the token itself. Phase 4: send it with `PUT /devices`.
            loggerService.info("Registered for remote notifications (\(deviceToken.count) bytes).")
        }

        func application(
            _ application: UIApplication,
            didFailToRegisterForRemoteNotificationsWithError error: any Error
        ) {
            loggerService.warning("Remote notification registration failed: \(error.localizedDescription)")
        }

        func application(
            _ application: UIApplication,
            didReceiveRemoteNotification userInfo: [AnyHashable: Any]
        ) async -> UIBackgroundFetchResult {
            // Phase 4: silent push → SyncEngine pull (+ outbox push) → `.newData`.
            loggerService.debug("Silent push received.")
            return .noData
        }
    }
#endif
