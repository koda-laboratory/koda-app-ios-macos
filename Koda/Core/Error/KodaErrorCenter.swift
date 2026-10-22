import Foundation

struct KodaErrorEvent: Sendable, Equatable, Identifiable {
    let id: UUID
    let error: KodaError
    let action: KodaErrorAction

    init(id: UUID = UUID(), error: KodaError, action: KodaErrorAction) {
        self.id = id
        self.error = error
        self.action = action
    }
}

/// Broadcasts each error to an independent stream per observer.
actor KodaErrorCenter {
    private var continuations: [UUID: AsyncStream<KodaErrorEvent>.Continuation] = [:]

    init() {}

    func events() -> AsyncStream<KodaErrorEvent> {
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

    func publish(_ error: KodaError, policy: KodaErrorHandlingPolicy) {
        guard policy.shouldPublish(error: error) else { return }

        publish(error, action: error.action)
    }

    func publish(_ error: KodaError, action: KodaErrorAction) {
        let event = KodaErrorEvent(error: error, action: action)
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func removeContinuation(for subscriptionID: UUID) {
        continuations.removeValue(forKey: subscriptionID)
    }
}
