import Foundation

@testable import Koda

/// Logger that drops every message.
struct SilentLoggerService: LoggerService {
    func debug(_ message: String, attributes: [String: String], file: String, function: String, line: UInt) {}
    func error(_ message: String, attributes: [String: String], file: String, function: String, line: UInt) {}
    func fault(_ message: String, attributes: [String: String], file: String, function: String, line: UInt) {}
    func info(_ message: String, attributes: [String: String], file: String, function: String, line: UInt) {}
    func warning(_ message: String, attributes: [String: String], file: String, function: String, line: UInt) {}
}

/// Refresh use case that counts its executions and suspends until released, so concurrent callers pile up.
actor ControlledRefreshSessionUseCase: RefreshSessionUseCase {
    private(set) var executionCount = 0
    private var outcome: Result<Void, KodaError>
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isReleased = false

    init(outcome: Result<Void, KodaError> = .success(())) {
        self.outcome = outcome
    }

    func execute() async throws(KodaError) {
        executionCount += 1
        if !isReleased {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
        try outcome.get()
    }

    func release() {
        isReleased = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    func setOutcome(_ outcome: Result<Void, KodaError>) {
        self.outcome = outcome
    }
}

/// Collects the events published by a `KodaErrorCenter`.
actor ErrorEventRecorder {
    private(set) var events: [KodaErrorEvent] = []

    func record(_ event: KodaErrorEvent) {
        events.append(event)
    }
}

/// Header provider with fixed values.
struct StaticHeaderProvider: HTTPHeaderProvider {
    var values: [String: String] = [:]

    func headers() async -> [String: String] {
        values
    }
}

/// Session token provider with a fixed token.
struct StaticSessionTokenProvider: SessionTokenProviding {
    let token: String?

    func accessToken() async -> String? {
        token
    }
}
