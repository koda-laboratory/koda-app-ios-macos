#if os(iOS)
    import UIKit
    import UserNotifications

    @MainActor
    final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
        /// `nil` while the process only hosts tests or previews.
        let coordinator: AppLifecycleCoordinator? =
            ProcessInfo.processInfo.skipsAppBootstrap ? nil : Assembly.makeAppLifecycleCoordinator()

        private var loggerService: any LoggerService {
            DependencyContainer.shared.required(LoggerService.self)
        }

        func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
        ) -> Bool {
            guard let coordinator else { return true }
            loggerService.debug("didFinishLaunching (iOS)")
            UNUserNotificationCenter.current().delegate = self

            // The BGAppRefreshTask handler must be registered before launch finishes.
            if let identifier = AppEnvironment.backgroundSyncTaskIdentifier {
                PlatformBackgroundRefreshRegistration.register(identifier: identifier) {
                    await coordinator.handleBackgroundRefresh() != .failed
                }
            }

            Task { await coordinator.applicationDidFinishLaunching() }
            return true
        }

        // MARK: - Remote notifications

        func application(
            _ application: UIApplication,
            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
        ) {
            // Never log the token itself.
            loggerService.info("Registered for remote notifications (\(deviceToken.count) bytes).")
            guard let coordinator else { return }
            Task { await coordinator.didRegisterForRemoteNotifications(deviceToken: deviceToken) }
        }

        func application(
            _ application: UIApplication,
            didFailToRegisterForRemoteNotificationsWithError error: any Error
        ) {
            loggerService.warning("Remote notification registration failed: \(error.localizedDescription)")
        }

        /// Silent push → SyncEngine pull (+ outbox push) → result within the ~30 s budget.
        func application(
            _ application: UIApplication,
            didReceiveRemoteNotification userInfo: [AnyHashable: Any]
        ) async -> UIBackgroundFetchResult {
            guard let coordinator else { return .noData }
            loggerService.debug("Silent push received.")
            return switch await coordinator.handleSilentPush() {
            case .newData: .newData
            case .noData, .skipped: .noData
            case .failed: .failed
            }
        }

        // MARK: - Visible notifications (defrost reminder)

        nonisolated func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .list, .sound]
        }

        nonisolated func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse
        ) async {
            guard let route = KodaNotification.route(for: response.notification.request.content.userInfo) else {
                return
            }
            await MainActor.run { coordinator?.open(route) }
        }
    }
#endif
