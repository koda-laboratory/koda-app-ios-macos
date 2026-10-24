import Foundation
import Observation

enum ProfileState: Sendable, Equatable {
    case idle
    case loggingOut
    case loggedOut
}

enum ProfileSettingsState: Sendable, Equatable {
    case idle
    case saving
    case saved
}

enum ProfileSyncState: Sendable, Equatable {
    case idle
    case syncing
}

enum ProfileIntent: Sendable {
    case appeared
    case saveSettings
    case setLockEnabled(Bool)
    case setLockTimeout(TimeInterval)
    case syncNow
    case logout
}

/// Perfil / Ajustes: household and members, meal times and shopping day, biometric lock, sync and logout.
@MainActor
@Observable
final class ProfileViewModel: FormViewModel {
    /// The use cases Profile depends on.
    struct UseCases {
        let observeHousehold: any ObserveHouseholdUseCase
        let observeSyncStatus: any ObserveSyncStatusUseCase
        let updateSettings: any UpdateHouseholdSettingsUseCase
        let getLockPolicy: any GetLockPolicyUseCase
        let updateLockPolicy: any UpdateLockPolicyUseCase
        let requestSync: any RequestSyncUseCase
        let logout: any LogoutUseCase
    }

    static let lockTimeouts: [TimeInterval] = [0, 60, 5 * 60, 15 * 60, 60 * 60]

    // MARK: - Properties

    private(set) var state = ProfileState.idle
    private(set) var settingsState = ProfileSettingsState.idle
    private(set) var syncState = ProfileSyncState.idle
    private(set) var household: HouseholdContext?
    private(set) var syncStatus = SyncStatus.initial
    private(set) var lockPolicy = BiometricLockPolicy.default
    var form = HouseholdSettingsFormState()
    var toast: Toast?

    /// Address of Koda's MCP server, for connecting an AI assistant (Claude, ChatGPT, Cursor…).
    let assistantServerURL: URL?

    @ObservationIgnored private let useCases: UseCases
    @ObservationIgnored private var observations: [Task<Void, Never>]?

    // MARK: - Lifecycle

    init(useCases: UseCases, assistantServerURL: URL? = nil) {
        self.useCases = useCases
        self.assistantServerURL = assistantServerURL
    }

    deinit {
        observations?.forEach { $0.cancel() }
    }

    // MARK: - Derived

    /// The form differs from the household settings.
    var hasUnsavedSettings: Bool {
        guard let settings = household?.household.settings else { return false }
        return form.settings != settings
    }

    // MARK: - Intents

    func send(_ intent: ProfileIntent) async {
        switch intent {
        case .appeared:
            lockPolicy = await useCases.getLockPolicy.execute()
            startObserving()
        case .saveSettings:
            await saveSettings()
        case .setLockEnabled(let isEnabled):
            lockPolicy.isEnabled = isEnabled
            await useCases.updateLockPolicy.execute(lockPolicy)
        case .setLockTimeout(let timeout):
            lockPolicy.backgroundTimeout = timeout
            await useCases.updateLockPolicy.execute(lockPolicy)
        case .syncNow:
            await syncNow()
        case .logout:
            await logout()
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observations == nil else { return }
        let households = useCases.observeHousehold.execute()
        let observeSyncStatus = useCases.observeSyncStatus
        observations = [
            Task { [weak self] in
                for await household in households {
                    guard let self else { return }
                    let wasPristine = !self.hasUnsavedSettings
                    self.household = household
                    if wasPristine, let settings = household?.household.settings {
                        self.form = HouseholdSettingsFormState(
                            slotTimes: settings.slotTimes,
                            shoppingWeekday: settings.shoppingWeekday
                        )
                    }
                }
            },
            Task { [weak self] in
                for await status in await observeSyncStatus.execute() { self?.syncStatus = status }
            },
        ]
    }

    private func saveSettings() async {
        guard let householdID = household?.household.id, settingsState != .saving, form.isValid else { return }
        settingsState = .saving
        do {
            try await useCases.updateSettings.execute(householdID: householdID, settings: form.settings)
            settingsState = .saved
        } catch {
            settingsState = .idle
            toast = .error(error)
        }
    }

    private func syncNow() async {
        guard syncState == .idle else { return }
        syncState = .syncing
        let outcome = await useCases.requestSync.execute()
        syncState = .idle
        toast =
            outcome == .failed
            ? Toast(messageKey: "profile.sync.failed", style: .error)
            : Toast(messageKey: "profile.sync.done")
    }

    private func logout() async {
        guard state == .idle else { return }
        state = .loggingOut
        do {
            try await useCases.logout.execute()
            state = .loggedOut
        } catch {
            state = .idle
            toast = .error(error)
        }
    }
}
