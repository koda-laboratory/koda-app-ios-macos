/// The cached user and household, updated whenever `/me` is refreshed. `nil` when signed out.
protocol ObserveHouseholdUseCase: Sendable {
    func execute() -> AsyncStream<HouseholdContext?>
}

final class ObserveHouseholdUseCaseImpl: ObserveHouseholdUseCase, Sendable {
    private let meRepository: any MeRepository

    init(meRepository: any MeRepository) {
        self.meRepository = meRepository
    }

    func execute() -> AsyncStream<HouseholdContext?> {
        meRepository.observe()
    }
}
