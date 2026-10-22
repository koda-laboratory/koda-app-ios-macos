import Foundation

/// Changes the meal times and the shopping weekday of the household (Profile). Needs the network.
protocol UpdateHouseholdSettingsUseCase: Sendable {
    @discardableResult
    func execute(householdID: UUID, settings: HouseholdSettings) async throws(KodaError) -> HouseholdContext
}

final class UpdateHouseholdSettingsUseCaseImpl: UpdateHouseholdSettingsUseCase, Sendable {
    private let meRepository: any MeRepository

    init(meRepository: any MeRepository) {
        self.meRepository = meRepository
    }

    @discardableResult
    func execute(householdID: UUID, settings: HouseholdSettings) async throws(KodaError) -> HouseholdContext {
        guard (1...7).contains(settings.shoppingWeekday) else {
            throw KodaError(type: .badRequest, reason: "The shopping weekday must be between 1 and 7.")
        }
        return try await meRepository.updateSettings(householdID: householdID, settings: settings)
    }
}
