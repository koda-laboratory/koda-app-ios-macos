import Foundation
import Observation

/// Session state the future root view switches on (login vs. tabs).
enum AppSessionState: Sendable, Equatable {
    case restoring
    case signedOut
    case signedIn(userID: String)
}

/// Composition-level glue between the platform lifecycle (app delegates, scene phase) and the use cases:
/// local-first launch, sync triggers, push registration, forced login and the biometric lock bookkeeping.
@MainActor
@Observable
final class AppLifecycleCoordinator {
    // MARK: - Properties

    private(set) var sessionState = AppSessionState.restoring

    @ObservationIgnored private let restoreSession: any RestoreSessionUseCase
    @ObservationIgnored private let login: any LoginUseCase
    @ObservationIgnored private let logout: any LogoutUseCase
    @ObservationIgnored private let expireSession: any ExpireSessionUseCase
    @ObservationIgnored private let refreshHousehold: any RefreshHouseholdUseCase
    @ObservationIgnored private let registerDevice: any RegisterDeviceUseCase
    @ObservationIgnored private let syncScheduler: any SyncScheduling
    @ObservationIgnored private let lockService: any BiometricLockService
    @ObservationIgnored private let errorCenter: KodaErrorCenter
    @ObservationIgnored private let loggerService: any LoggerService
    @ObservationIgnored private let registerForRemoteNotifications: @MainActor () -> Void
    @ObservationIgnored private var errorEventsTask: Task<Void, Never>?

    // MARK: - Lifecycle

    init(
        restoreSession: any RestoreSessionUseCase,
        login: any LoginUseCase,
        logout: any LogoutUseCase,
        expireSession: any ExpireSessionUseCase,
        refreshHousehold: any RefreshHouseholdUseCase,
        registerDevice: any RegisterDeviceUseCase,
        syncScheduler: any SyncScheduling,
        lockService: any BiometricLockService,
        errorCenter: KodaErrorCenter,
        loggerService: any LoggerService,
        registerForRemoteNotifications: @escaping @MainActor () -> Void
    ) {
        self.restoreSession = restoreSession
        self.login = login
        self.logout = logout
        self.expireSession = expireSession
        self.refreshHousehold = refreshHousehold
        self.registerDevice = registerDevice
        self.syncScheduler = syncScheduler
        self.lockService = lockService
        self.errorCenter = errorCenter
        self.loggerService = loggerService
        self.registerForRemoteNotifications = registerForRemoteNotifications
    }

    deinit {
        errorEventsTask?.cancel()
    }

    // MARK: - Launch

    /// Cold start: restores the session from the Keychain without network and starts syncing in the background.
    func applicationDidFinishLaunching() async {
        observeForcedLogin()
        await lockService.applicationDidLaunch()

        guard let session = await restoreSession.execute() else {
            sessionState = .signedOut
            return
        }
        sessionState = .signedIn(userID: session.userId)
        await startSignedInServices(trigger: .launch)

        // Keep the cached household and members current; offline is fine (the cache stays).
        Task { [refreshHousehold] in try? await refreshHousehold.execute() }
    }

    // MARK: - Scene phase

    func sceneDidBecomeActive() async {
        await lockService.applicationWillEnterForeground()
        guard case .signedIn = sessionState else { return }
        await syncScheduler.requestSync(.foreground)
    }

    func sceneDidEnterBackground() async {
        await lockService.applicationDidEnterBackground()
    }

    // MARK: - Session

    /// Password login, then `/me`, push registration and a first sync.
    func signIn(email: String, password: String) async throws(KodaError) {
        let context = try await login.execute(email: email, password: password)
        sessionState = .signedIn(userID: context.userID.uuidString.lowercased())
        await startSignedInServices(trigger: .login)
    }

    func signOut() async throws(KodaError) {
        try await logout.execute()
        await lockService.reset()
        sessionState = .signedOut
    }

    // MARK: - Push and background

    func didRegisterForRemoteNotifications(deviceToken: Data) async {
        do {
            try await registerDevice.execute(apnsToken: deviceToken)
        } catch {
            loggerService.warning("Device registration failed.", attributes: ["error.type": error.type.rawValue])
        }
    }

    /// Silent push (`content-available`): pull (and push the outbox) before the system's time runs out.
    func handleSilentPush() async -> SyncOutcome {
        await syncScheduler.syncNow(.silentPush)
    }

    /// `BGAppRefreshTask` (iOS).
    func handleBackgroundRefresh() async -> SyncOutcome {
        await syncScheduler.syncNow(.backgroundRefresh)
    }

    // MARK: - Private Methods

    private func startSignedInServices(trigger: SyncTrigger) async {
        await syncScheduler.start()
        await syncScheduler.requestSync(trigger)
        registerForRemoteNotifications()
    }

    /// `invalid_grant` (or an equivalent rejected refresh) shows the login again but keeps local data.
    private func observeForcedLogin() {
        guard errorEventsTask == nil else { return }
        let errorCenter = errorCenter
        errorEventsTask = Task { [weak self] in
            for await event in await errorCenter.events() where event.action == .forceLogin {
                await self?.handleForcedLogin()
            }
        }
    }

    private func handleForcedLogin() async {
        guard case .signedIn = sessionState else { return }
        loggerService.warning("🔐 [AUTH][SESSION] Session expired; login required. Local data is kept.")
        await expireSession.execute()
        sessionState = .signedOut
    }
}
