/// Refreshes the cached `/me` (profile, household, members).
protocol RefreshHouseholdUseCase: Sendable {
    @discardableResult
    func execute() async throws(KodaError) -> HouseholdContext
}

final class RefreshHouseholdUseCaseImpl: RefreshHouseholdUseCase, Sendable {
    private let meRepository: any MeRepository

    init(meRepository: any MeRepository) {
        self.meRepository = meRepository
    }

    @discardableResult
    func execute() async throws(KodaError) -> HouseholdContext {
        try await meRepository.refresh()
    }
}
