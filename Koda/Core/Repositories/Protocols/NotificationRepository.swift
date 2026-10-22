/// Visible notification permission (asked the first time a product is marked as frozen).
protocol NotificationRepository: Sendable {
    func authorization() async -> NotificationAuthorization
    func requestAuthorization() async throws(KodaError) -> Bool
}
