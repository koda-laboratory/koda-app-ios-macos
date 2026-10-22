import Foundation
import Testing

@testable import Koda

private actor RecordingLockService: BiometricLockService {
    private var currentPolicy = BiometricLockPolicy.default

    func state() -> AppLockState { .unlocked }
    func stateUpdates() -> AsyncStream<AppLockState> { AsyncStream { $0.yield(.unlocked) } }
    func policy() -> BiometricLockPolicy { currentPolicy }
    func updatePolicy(_ policy: BiometricLockPolicy) { currentPolicy = policy }
    func applicationDidLaunch() -> AppLockState { .unlocked }
    func applicationDidEnterBackground() {}
    func applicationWillEnterForeground() -> AppLockState { .unlocked }
    func unlock(reason: String) throws(KodaError) -> AppLockState { .unlocked }
    func reset() {}
}

private actor RecordingLogoutUseCase: LogoutUseCase {
    private(set) var count = 0

    func execute() async throws(KodaError) {
        count += 1
    }
}

@MainActor
@Suite("Profile")
struct ProfileViewModelTests {
    private func makeViewModel(
        _ environment: FeatureEnvironment,
        lock: RecordingLockService,
        logout: RecordingLogoutUseCase
    ) -> ProfileViewModel {
        ProfileViewModel(
            useCases: ProfileViewModel.UseCases(
                observeHousehold: environment.observeHousehold,
                observeSyncStatus: ObserveSyncStatusUseCaseImpl(syncScheduler: environment.syncScheduler),
                updateSettings: UpdateHouseholdSettingsUseCaseImpl(meRepository: environment.meRepository),
                getLockPolicy: GetLockPolicyUseCaseImpl(lockService: lock),
                updateLockPolicy: UpdateLockPolicyUseCaseImpl(lockService: lock),
                requestSync: RequestSyncUseCaseImpl(syncScheduler: environment.syncScheduler),
                logout: logout
            )
        )
    }

    @Test("Settings load from the household and save through PATCH, updating the cache")
    func settings() async throws {
        let database = try await TestDatabase.make()
        let response = MeHouseholdDTO(
            id: TestDatabase.householdID,
            name: "Casa",
            timezone: "Europe/Madrid",
            role: "owner",
            members: [],
            slotTimes: ["breakfast": "08:30", "lunch": "14:30", "snack": "18:00", "dinner": "21:00"],
            shoppingWeekday: 6
        )
        let environment = FeatureEnvironment(
            database: database,
            meRemote: StubMeRemoteDataSource(settingsResponse: response)
        )
        let viewModel = makeViewModel(environment, lock: RecordingLockService(), logout: RecordingLogoutUseCase())
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.household != nil })
        #expect(viewModel.form.shoppingWeekday == 5)
        #expect(!viewModel.hasUnsavedSettings)

        viewModel.form.shoppingWeekday = 6
        viewModel.form.slotTimes.breakfast = LocalTime(hour: 8, minute: 30)
        viewModel.form.slotTimes.dinner = LocalTime(hour: 21, minute: 0)
        #expect(viewModel.hasUnsavedSettings)
        await viewModel.send(.saveSettings)
        #expect(viewModel.settingsState == .saved)
        #expect(await eventually { viewModel.household?.household.settings.shoppingWeekday == 6 })
        #expect(viewModel.household?.household.settings.slotTimes.breakfast == LocalTime(hour: 8, minute: 30))
        #expect(!viewModel.hasUnsavedSettings)
    }

    @Test("Offline settings changes show a toast and keep the form")
    func settingsOffline() async throws {
        let environment = try await FeatureEnvironment.make()
        let viewModel = makeViewModel(environment, lock: RecordingLockService(), logout: RecordingLogoutUseCase())
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.household != nil })
        viewModel.form.shoppingWeekday = 1
        await viewModel.send(.saveSettings)
        #expect(viewModel.settingsState == .idle)
        #expect(viewModel.toast?.messageKey == "error.type.no-internet")
        #expect(viewModel.form.shoppingWeekday == 1)
    }

    @Test("Lock preferences, manual sync and logout")
    func lockSyncLogout() async throws {
        let environment = try await FeatureEnvironment.make()
        let lock = RecordingLockService()
        let logout = RecordingLogoutUseCase()
        let viewModel = makeViewModel(environment, lock: lock, logout: logout)
        await viewModel.send(.appeared)
        await viewModel.send(.setLockEnabled(false))
        await viewModel.send(.setLockTimeout(60))
        #expect(await lock.policy() == BiometricLockPolicy(isEnabled: false, backgroundTimeout: 60))

        await viewModel.send(.syncNow)
        #expect(await environment.syncScheduler.syncTriggers == [.manual])
        #expect(viewModel.toast?.messageKey == "profile.sync.done")

        await viewModel.send(.logout)
        #expect(viewModel.state == .loggedOut)
        #expect(await logout.count == 1)
    }

    @Test("The shell exposes the sync status and the household")
    func shell() async throws {
        let environment = try await FeatureEnvironment.make()
        let viewModel = ShellViewModel(
            observeSyncStatus: ObserveSyncStatusUseCaseImpl(syncScheduler: environment.syncScheduler),
            observeHousehold: environment.observeHousehold
        )
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.household?.displayName == "Test" })
        #expect(viewModel.syncStatus == .initial)
    }
}
