import Foundation

/// Pending planning drafts (for example the one Claude prepares through the MCP).
protocol ObservePendingDraftsUseCase: Sendable {
    func execute() -> AsyncStream<[MealPlanDraft]>
}

final class ObservePendingDraftsUseCaseImpl: ObservePendingDraftsUseCase, Sendable {
    private let repository: any PlanningRepository

    init(repository: any PlanningRepository) {
        self.repository = repository
    }

    func execute() -> AsyncStream<[MealPlanDraft]> {
        repository.observePendingDrafts()
    }
}
