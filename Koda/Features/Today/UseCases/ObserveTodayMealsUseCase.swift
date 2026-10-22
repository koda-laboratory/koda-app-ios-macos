/// The meals planned for one day (normally today in the household time zone), with their eaten state.
protocol ObserveTodayMealsUseCase: Sendable {
    func execute(day: LocalDay) -> AsyncStream<TodayMeals>
}

final class ObserveTodayMealsUseCaseImpl: ObserveTodayMealsUseCase, Sendable {
    private let planningRepository: any PlanningRepository

    init(planningRepository: any PlanningRepository) {
        self.planningRepository = planningRepository
    }

    func execute(day: LocalDay) -> AsyncStream<TodayMeals> {
        planningRepository.observeEntries(from: day, through: day)
            .mapStream { TodayMeals(day: day, meals: $0) }
    }
}
