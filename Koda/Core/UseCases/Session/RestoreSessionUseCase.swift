/// Restores the stored session at launch without touching the network (local-first launch). The access token
/// is refreshed lazily: proactively before a request when it expires within 60 s, or on a 401.
protocol RestoreSessionUseCase: Sendable {
    func execute() async -> UserSession?
}

final class RestoreSessionUseCaseImpl: RestoreSessionUseCase, Sendable {
    private let sessionService: any SessionService

    init(sessionService: any SessionService) {
        self.sessionService = sessionService
    }

    func execute() async -> UserSession? {
        await sessionService.restore()
    }
}
