import Foundation
import UserNotifications

/// Permission for visible notifications (the defrost reminder), on iPhone and Mac.
enum NotificationAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}

/// `UNUserNotificationCenter` access.
protocol UserNotificationDataSource: Sendable {
    func authorization() async -> NotificationAuthorization
    func requestAuthorization() async throws(KodaError) -> Bool
}

final class UserNotificationCenterDataSource: UserNotificationDataSource, Sendable {
    func authorization() async -> NotificationAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return switch settings.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .authorized
        }
    }

    func requestAuthorization() async throws(KodaError) -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            throw KodaError(type: .internal, reason: "Notification authorization failed: \(error.localizedDescription)")
        }
    }
}
