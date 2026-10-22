import Foundation

/// "No lo comimos": the meal stops counting as eaten (its consumption is tombstoned) and the server does not
/// auto-log it again (`skipped_at`).
protocol SkipMealUseCase: Sendable {
    func execute(entryID: UUID) async throws(KodaError)
}

final class SkipMealUseCaseImpl: SkipMealUseCase, Sendable {
    private let repository: any PlanningRepository
    private let clock: @Sendable () -> Date

    init(repository: any PlanningRepository, clock: @escaping @Sendable () -> Date = { .now }) {
        self.repository = repository
        self.clock = clock
    }

    func execute(entryID: UUID) async throws(KodaError) {
        try await repository.skipEntry(id: entryID, at: clock())
    }
}
