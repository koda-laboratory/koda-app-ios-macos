import Foundation

/// Owns the persisted `UserSession` and broadcasts its changes. Login, restore, forced login and logout use
/// cases build on it.
protocol SessionService: SessionTokenProviding, SessionExpiryProviding, Sendable {
    func current(errorHandling: KodaErrorHandlingPolicy) async throws(KodaError) -> UserSession?
    func delete() async throws(KodaError)
    func events() async -> AsyncStream<UserSession?>
    @discardableResult func restore() async -> UserSession?
    func save(_ session: UserSession, errorHandling: KodaErrorHandlingPolicy) async throws(KodaError)
}

extension SessionService {
    func current() async throws(KodaError) -> UserSession? {
        try await current(errorHandling: .automatic)
    }

    func save(_ session: UserSession) async throws(KodaError) {
        try await save(session, errorHandling: .automatic)
    }
}

actor SessionServiceImpl: SessionService {
    // MARK: - Properties

    private let errorCenter: KodaErrorCenter
    private let loggerService: any LoggerService
    private let repository: any SessionRepository
    private let clock: @Sendable () -> Date
    private var continuations: [UUID: AsyncStream<UserSession?>.Continuation] = [:]

    // MARK: - Lifecycle

    init(
        repository: any SessionRepository,
        errorCenter: KodaErrorCenter,
        loggerService: any LoggerService,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.repository = repository
        self.errorCenter = errorCenter
        self.loggerService = loggerService
        self.clock = clock
    }

    // MARK: - Public Methods

    func current(errorHandling: KodaErrorHandlingPolicy) async throws(KodaError) -> UserSession? {
        do {
            return try await repository.read()
        } catch {
            throw await mapStorageError(error, policy: errorHandling)
        }
    }

    /// Restores the stored session without touching the network (local-first launch).
    @discardableResult
    func restore() async -> UserSession? {
        let session = try? await current(errorHandling: .suppressed)
        publish(session)
        return session
    }

    func save(_ session: UserSession, errorHandling: KodaErrorHandlingPolicy) async throws(KodaError) {
        do {
            try await repository.save(session)
            publish(session)
        } catch {
            throw await mapStorageError(error, policy: errorHandling)
        }
    }

    func delete() async throws(KodaError) {
        do {
            try await repository.delete()
            publish(nil)
        } catch {
            throw await mapStorageError(error, policy: .automatic)
        }
    }

    func accessToken() async -> String? {
        try? await current(errorHandling: .suppressed)?.accessToken
    }

    func sessionNeedsRefresh() async -> Bool {
        guard let session = try? await current(errorHandling: .suppressed) else { return false }
        return session.needsRefresh(now: clock())
    }

    // MARK: - Stream

    func events() -> AsyncStream<UserSession?> {
        let subscriptionID = UUID()

        return AsyncStream { continuation in
            continuations[subscriptionID] = continuation
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(for: subscriptionID)
                }
            }
        }
    }

    private func publish(_ session: UserSession?) {
        for continuation in continuations.values {
            continuation.yield(session)
        }
    }

    private func mapStorageError(_ error: any Error, policy: KodaErrorHandlingPolicy) async -> KodaError {
        let mappedError = KodaError(type: .storage, reason: "Unable to access the locally stored user session.")
        await errorCenter.publish(mappedError, policy: policy)
        loggerService.error("Session storage failed: \(String(describing: error))")
        return mappedError
    }

    private func removeContinuation(for subscriptionID: UUID) {
        continuations.removeValue(forKey: subscriptionID)
    }
}
