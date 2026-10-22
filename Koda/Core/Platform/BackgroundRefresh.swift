import Foundation

#if os(iOS)
    import BackgroundTasks
#endif

/// Schedules the next background refresh (iOS `BGAppRefreshTask`). The Mac relies on silent pushes and on
/// syncing at activation, so it is a no-op there.
protocol BackgroundRefreshScheduling: Sendable {
    func scheduleNextRefresh()
}

struct PlatformBackgroundRefreshScheduler: BackgroundRefreshScheduling {
    /// iOS decides the actual time; this is only the earliest one.
    static let minimumInterval: TimeInterval = 15 * 60

    let identifier: String?

    init(identifier: String? = AppEnvironment.backgroundSyncTaskIdentifier) {
        self.identifier = identifier
    }

    func scheduleNextRefresh() {
        #if os(iOS)
            guard let identifier else { return }
            let request = BGAppRefreshTaskRequest(identifier: identifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: Self.minimumInterval)
            // Fails on the simulator and when Background App Refresh is disabled; silent pushes still work.
            try? BGTaskScheduler.shared.submit(request)
        #endif
    }
}

#if os(iOS)
    /// Registers the `BGAppRefreshTask` handler. Must run before `application(_:didFinishLaunchingWithOptions:)`
    /// returns. Nonisolated on purpose: the launch handler runs on a background queue.
    enum PlatformBackgroundRefreshRegistration {
        nonisolated static func register(identifier: String, handler: @escaping @Sendable () async -> Bool) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
                let box = BackgroundTaskBox(task: task)
                let work = Task {
                    let success = await handler()
                    box.task.setTaskCompleted(success: success)
                }
                task.expirationHandler = {
                    work.cancel()
                }
            }
        }
    }

    // `BGTask` is not `Sendable`, but its completion API is documented as callable from any thread and the task
    // is completed exactly once from the work task above.
    // swiftlint:disable:next no_unchecked_sendable
    private final class BackgroundTaskBox: @unchecked Sendable {
        let task: BGTask

        init(task: BGTask) {
            self.task = task
        }
    }
#endif
