final class NotificationRepositoryImpl: NotificationRepository, Sendable {
    private let dataSource: any UserNotificationDataSource

    init(dataSource: any UserNotificationDataSource) {
        self.dataSource = dataSource
    }

    func authorization() async -> NotificationAuthorization {
        await dataSource.authorization()
    }

    func requestAuthorization() async throws(KodaError) -> Bool {
        try await dataSource.requestAuthorization()
    }
}
