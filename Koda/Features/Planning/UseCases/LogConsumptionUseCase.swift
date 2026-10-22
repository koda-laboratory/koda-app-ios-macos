import Foundation

/// Records that a recipe was eaten ("Marcar como comido"), linked to its planned meal when there is one.
protocol LogConsumptionUseCase: Sendable {
    @discardableResult
    func execute(_ input: NewConsumption) async throws(KodaError) -> Consumption
}

final class LogConsumptionUseCaseImpl: LogConsumptionUseCase, Sendable {
    private let repository: any PlanningRepository

    init(repository: any PlanningRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute(_ input: NewConsumption) async throws(KodaError) -> Consumption {
        if let servings = input.servings, servings <= 0 {
            throw KodaError(type: .badRequest, reason: "Servings must be positive.")
        }
        return try await repository.logConsumption(input)
    }
}
