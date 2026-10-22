import Foundation

/// Discards a draft on the server (its entries are tombstoned) and pulls the result. Needs the network.
protocol DiscardDraftUseCase: Sendable {
    @discardableResult
    func execute(draftID: UUID) async throws(KodaError) -> Int
}

final class DiscardDraftUseCaseImpl: DiscardDraftUseCase, Sendable {
    private let repository: any PlanningRepository
    private let syncScheduler: any SyncScheduling

    init(repository: any PlanningRepository, syncScheduler: any SyncScheduling) {
        self.repository = repository
        self.syncScheduler = syncScheduler
    }

    @discardableResult
    func execute(draftID: UUID) async throws(KodaError) -> Int {
        let entries = try await repository.discardDraft(id: draftID)
        await syncScheduler.syncNow(.manual)
        return entries
    }
}
