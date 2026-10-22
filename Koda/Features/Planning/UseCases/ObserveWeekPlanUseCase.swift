import Foundation

/// The week (Monday–Sunday) that contains `day`, with its planned meals.
protocol ObserveWeekPlanUseCase: Sendable {
    func execute(containing day: LocalDay) -> AsyncStream<WeekPlan>
}

final class ObserveWeekPlanUseCaseImpl: ObserveWeekPlanUseCase, Sendable {
    private let repository: any PlanningRepository

    init(repository: any PlanningRepository) {
        self.repository = repository
    }

    func execute(containing day: LocalDay) -> AsyncStream<WeekPlan> {
        let start = day.startOfWeek
        return repository.observeEntries(from: start, through: start.adding(days: 6))
            .mapStream { WeekPlan(containing: start, entries: $0) }
    }
}
