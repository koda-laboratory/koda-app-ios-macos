import Foundation
import Testing

@testable import Koda

@Suite("HTTPSessionRecovery single-flight")
struct HTTPSessionRecoveryTests {
    private let unauthorized = KodaError(type: .auth, reason: "JWT expired", rawCode: "bad_jwt", statusCode: 401)

    private func makeRecovery(
        useCase: ControlledRefreshSessionUseCase,
        errorCenter: KodaErrorCenter = KodaErrorCenter()
    ) -> HTTPSessionRecoveryImpl {
        HTTPSessionRecoveryImpl(
            refreshSessionUseCaseProvider: { useCase },
            errorCenter: errorCenter,
            loggerService: SilentLoggerService()
        )
    }

    @Test("Concurrent 401s share one refresh")
    func concurrentCallersShareOneRefresh() async throws {
        let useCase = ControlledRefreshSessionUseCase()
        let recovery = makeRecovery(useCase: useCase)
        let generation = await recovery.generation()
        let error = unauthorized

        let results = await withTaskGroup(of: SessionRecoveryResult.self) { group in
            for _ in 0..<8 {
                group.addTask { await recovery.recoverSession(after: generation, triggeredBy: error) }
            }
            // Let every caller reach the actor before the single refresh completes.
            while await useCase.executionCount == 0 {
                await Task.yield()
            }
            try? await Task.sleep(for: .milliseconds(50))
            await useCase.release()
            return await group.reduce(into: [SessionRecoveryResult]()) { $0.append($1) }
        }

        #expect(results.count == 8)
        #expect(results.allSatisfy { $0 == .recovered })
        #expect(await useCase.executionCount == 1)
        #expect(await recovery.generation() == generation + 1)
    }

    @Test("A request sent before the last refresh reuses its result")
    func staleGenerationReusesLatestResult() async {
        let useCase = ControlledRefreshSessionUseCase()
        await useCase.release()
        let recovery = makeRecovery(useCase: useCase)

        let first = await recovery.recoverSession(after: 0, triggeredBy: unauthorized)
        let stale = await recovery.recoverSession(after: 0, triggeredBy: unauthorized)
        #expect(first == .recovered)
        #expect(stale == .recovered)
        #expect(await useCase.executionCount == 1)

        let next = await recovery.recoverSession(after: 1, triggeredBy: unauthorized)
        #expect(next == .recovered)
        #expect(await useCase.executionCount == 2)
    }

    @Test("A rejected refresh token forces login")
    func invalidGrantForcesLogin() async throws {
        let rejection = KodaError(
            type: .auth,
            reason: "Invalid Refresh Token",
            rawCode: "invalid_grant",
            statusCode: 400
        )
        let useCase = ControlledRefreshSessionUseCase(outcome: .failure(rejection))
        await useCase.release()
        let errorCenter = KodaErrorCenter()
        let recorder = ErrorEventRecorder()
        let events = await errorCenter.events()
        let listener = Task {
            for await event in events {
                await recorder.record(event)
            }
        }
        defer { listener.cancel() }

        let result = await makeRecovery(useCase: useCase, errorCenter: errorCenter)
            .recoverSession(after: 0, triggeredBy: unauthorized)

        #expect(result == .failed(rejection))
        try await waitUntil { await recorder.events.count == 1 }
        #expect(await recorder.events.first?.action == .forceLogin)
    }

    @Test("Offline refresh failures keep the session")
    func networkFailureDoesNotForceLogin() async throws {
        let offline = KodaError(type: .noInternet, reason: "The Internet connection appears to be offline.")
        let useCase = ControlledRefreshSessionUseCase(outcome: .failure(offline))
        await useCase.release()
        let errorCenter = KodaErrorCenter()
        let recorder = ErrorEventRecorder()
        let events = await errorCenter.events()
        let listener = Task {
            for await event in events {
                await recorder.record(event)
            }
        }
        defer { listener.cancel() }

        let result = await makeRecovery(useCase: useCase, errorCenter: errorCenter)
            .recoverSession(after: 0, triggeredBy: unauthorized)

        #expect(result == .failed(offline))
        try await Task.sleep(for: .milliseconds(50))
        #expect(await recorder.events.isEmpty)
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: @Sendable () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while await !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Condition not met before the timeout")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
