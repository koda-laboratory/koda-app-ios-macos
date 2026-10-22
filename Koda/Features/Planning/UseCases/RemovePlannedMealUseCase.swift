import Foundation

protocol RemovePlannedMealUseCase: Sendable {
    func execute(entryID: UUID) async throws(KodaError)
}

final class RemovePlannedMealUseCaseImpl: RemovePlannedMealUseCase, Sendable {
    private let repository: any PlanningRepository

    init(repository: any PlanningRepository) {
        self.repository = repository
    }

    func execute(entryID: UUID) async throws(KodaError) {
        try await repository.removeEntry(id: entryID)
    }
}
