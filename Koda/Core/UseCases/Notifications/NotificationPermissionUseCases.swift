/// Whether the app may show the defrost reminder.
protocol GetNotificationAuthorizationUseCase: Sendable {
    func execute() async -> NotificationAuthorization
}

final class GetNotificationAuthorizationUseCaseImpl: GetNotificationAuthorizationUseCase, Sendable {
    private let repository: any NotificationRepository

    init(repository: any NotificationRepository) {
        self.repository = repository
    }

    func execute() async -> NotificationAuthorization {
        await repository.authorization()
    }
}

/// Shows the system permission dialog (after Koda's own explanation).
protocol RequestNotificationAuthorizationUseCase: Sendable {
    @discardableResult
    func execute() async throws(KodaError) -> Bool
}

final class RequestNotificationAuthorizationUseCaseImpl: RequestNotificationAuthorizationUseCase, Sendable {
    private let repository: any NotificationRepository

    init(repository: any NotificationRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute() async throws(KodaError) -> Bool {
        try await repository.requestAuthorization()
    }
}
