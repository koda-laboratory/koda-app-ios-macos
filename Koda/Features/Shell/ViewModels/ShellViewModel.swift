import Foundation
import Observation

enum ShellIntent: Sendable {
    case appeared
}

/// The signed-in shell: sync status for the offline indicator and the household for the sidebar footer.
@MainActor
@Observable
final class ShellViewModel: MVIViewModel {
    // MARK: - Properties

    private(set) var syncStatus = SyncStatus.initial
    private(set) var household: HouseholdContext?

    @ObservationIgnored private let observeSyncStatus: any ObserveSyncStatusUseCase
    @ObservationIgnored private let observeHousehold: any ObserveHouseholdUseCase
    @ObservationIgnored private var observations: [Task<Void, Never>]?

    // MARK: - Lifecycle

    init(observeSyncStatus: any ObserveSyncStatusUseCase, observeHousehold: any ObserveHouseholdUseCase) {
        self.observeSyncStatus = observeSyncStatus
        self.observeHousehold = observeHousehold
    }

    deinit {
        observations?.forEach { $0.cancel() }
    }

    // MARK: - Intents

    func send(_ intent: ShellIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observations == nil else { return }
        let observeSyncStatus = observeSyncStatus
        let households = observeHousehold.execute()
        observations = [
            Task { [weak self] in
                for await status in await observeSyncStatus.execute() {
                    self?.syncStatus = status
                }
            },
            Task { [weak self] in
                for await household in households {
                    self?.household = household
                }
            },
        ]
    }
}
