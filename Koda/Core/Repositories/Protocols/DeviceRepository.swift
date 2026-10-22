import Foundation

/// This installation as a push target (`devices` on the backend).
protocol DeviceRepository: Sendable {
    /// Stable per-installation UUID kept in the Keychain; also the `device_id` sent with `/sync/push`.
    func installationID() async throws(KodaError) -> String
    func register(apnsToken: Data) async throws(KodaError)
    func unregister() async throws(KodaError)
}
