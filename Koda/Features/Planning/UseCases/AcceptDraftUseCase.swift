import Foundation

/// Accepts a draft on the server (atomic) and pulls the result. Needs the network.
protocol AcceptDraftUseCase: Sendable {
    @discardableResult
    func execute(draftID: UUID) async throws(KodaError) -> Int
}

final class AcceptDraftUseCaseImpl: AcceptDraftUseCase, Sendable {
    private let repository: any PlanningRepository
    private let syncScheduler: any SyncScheduling

    init(repository: any PlanningRepository, syncScheduler: any SyncScheduling) {
        self.repository = repository
        self.syncScheduler = syncScheduler
    }

    @discardableResult
    func execute(draftID: UUID) async throws(KodaError) -> Int {
        let entries = try await repository.acceptDraft(id: draftID)
        await syncScheduler.syncNow(.manual)
        return entries
    }
}
