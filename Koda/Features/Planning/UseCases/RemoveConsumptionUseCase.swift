import Foundation

/// Undoes "Marcar como comido".
protocol RemoveConsumptionUseCase: Sendable {
    func execute(consumptionID: UUID) async throws(KodaError)
}

final class RemoveConsumptionUseCaseImpl: RemoveConsumptionUseCase, Sendable {
    private let repository: any PlanningRepository

    init(repository: any PlanningRepository) {
        self.repository = repository
    }

    func execute(consumptionID: UUID) async throws(KodaError) {
        try await repository.removeConsumption(id: consumptionID)
    }
}
