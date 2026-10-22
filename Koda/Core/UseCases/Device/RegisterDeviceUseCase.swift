import Foundation

/// Uploads this installation's APNs token (`PUT /devices`) when a user is signed in. Called every time the
/// system delivers a token (after login and at each launch with a session).
protocol RegisterDeviceUseCase: Sendable {
    func execute(apnsToken: Data) async throws(KodaError)
}

final class RegisterDeviceUseCaseImpl: RegisterDeviceUseCase, Sendable {
    private let deviceRepository: any DeviceRepository
    private let sessionService: any SessionService

    init(deviceRepository: any DeviceRepository, sessionService: any SessionService) {
        self.deviceRepository = deviceRepository
        self.sessionService = sessionService
    }

    func execute(apnsToken: Data) async throws(KodaError) {
        guard try await sessionService.current(errorHandling: .suppressed) != nil else { return }
        try await deviceRepository.register(apnsToken: apnsToken)
    }
}
