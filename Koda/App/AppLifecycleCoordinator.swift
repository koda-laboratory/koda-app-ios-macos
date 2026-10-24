import Foundation
import Observation

/// Session state the root view switches on (login vs. tabs).
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
    /// The app-wide navigation state, shared by the main window, notifications and Mac menu commands.
    let router = AppRouter()

    @ObservationIgnored private let restoreSession: any RestoreSessionUseCase
    @ObservationIgnored private let login: any LoginUseCase
    @ObservationIgnored private let logout: any LogoutUseCase
    @ObservationIgnored private let expireSession: any ExpireSessionUseCase
    @ObservationIgnored private let refreshHousehold: any RefreshHouseholdUseCase
    @ObservationIgnored private let registerDevice: any RegisterDeviceUseCase
    @ObservationIgnored private let syncScheduler: any SyncScheduling
    @ObservationIgnored private let widgetMenu: any WidgetMenuService
    @ObservationIgnored private let intentIndexing: any IntentIndexing
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
        widgetMenu: any WidgetMenuService,
        intentIndexing: any IntentIndexing,
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
        self.widgetMenu = widgetMenu
        self.intentIndexing = intentIndexing
        self.lockService = lockService
        self.errorCenter = errorCenter
        self.loggerService = loggerService
        self.registerForRemoteNotifications = registerForRemoteNotifications
        IntentNavigator.shared.router = router
    }

    deinit {
        errorEventsTask?.cancel()
    }

    // MARK: - Launch

    /// Cold start: restores the session from the Keychain without network and starts syncing in the background.
    func applicationDidFinishLaunching() async {
        observeForcedLogin()
        KodaNotification.registerCategories()

        guard let session = await restoreSession.execute() else {
            await lockService.reset()
            sessionState = .signedOut
            return
        }
        // A returning user signs in with Face ID / Touch ID (the login screen with biometrics), never twice.
        await lockService.applicationDidLaunch()
        sessionState = .signedIn(userID: session.userId)
        await startSignedInServices(trigger: .launch)

        // Keep the cached household and members current; offline is fine (the cache stays).
        Task { [refreshHousehold] in try? await refreshHousehold.execute() }
    }

    // MARK: - Scene phase

    func sceneDidBecomeActive() async {
        guard case .signedIn = sessionState else { return }
        await lockService.applicationWillEnterForeground()
        // After a day change the widgets' menu starts again from the new today.
        await widgetMenu.start()
        await syncScheduler.requestSync(.foreground)
    }

    func sceneDidEnterBackground() async {
        guard case .signedIn = sessionState else { return }
        await lockService.applicationDidEnterBackground()
    }

    // MARK: - Session

    /// Password login, then `/me`, push registration and a first sync.
    func signIn(email: String, password: String) async throws(KodaError) {
        let context = try await login.execute(email: email, password: password)
        await didSignIn(userID: context.userID.uuidString.lowercased())
    }

    /// The login screen completed `LoginUseCase`: enter the app and start sync and push registration.
    func didSignIn(userID: String) async {
        // The password already proved who this is: no biometric step on top of it.
        await lockService.markUnlocked()
        router.popToRoot(in: router.selectedTab)
        router.selectedTab = .today
        sessionState = .signedIn(userID: userID)
        await startSignedInServices(trigger: .login)
    }

    func signOut() async throws(KodaError) {
        try await logout.execute()
        didSignOut()
    }

    /// Profile completed `LogoutUseCase` (which already cleared the session, the database and the lock).
    func didSignOut() {
        for tab in AppTab.allCases {
            router.popToRoot(in: tab)
        }
        sessionState = .signedOut
        Task { [widgetMenu, intentIndexing] in
            await widgetMenu.stopAndClear()
            await intentIndexing.stopAndClear()
        }
    }

    // MARK: - Deep links

    /// `koda://today`, `koda://shopping` and `koda://shopping/add` (widgets and the Control Center control).
    func open(url: URL) {
        guard case .signedIn = sessionState, url.scheme == "koda" else { return }
        switch url.host() {
        case "today": router.selectedTab = .today
        case "planning": router.selectedTab = .planning
        case "shopping" where url.path() == "/add": router.request(.addToShopping)
        case "shopping": router.selectedTab = .shopping
        default: break
        }
    }

    // MARK: - Notifications

    /// A tapped defrost notification (default tap or "Ver receta").
    func open(_ route: AppRoute) {
        guard case .signedIn = sessionState else { return }
        router.open(route)
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
        await widgetMenu.start()
        await intentIndexing.start()
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
