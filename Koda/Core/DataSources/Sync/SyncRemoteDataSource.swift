/// `/sync/push` and `/sync/pull` of the `api` Edge Function. Only the `SyncEngine` uses it.
protocol SyncRemoteDataSource: Sendable {
    func push(_ body: SyncPushRequestDTO) async throws(KodaError) -> SyncPushResponseDTO
    func pull(cursor: Int64, limit: Int) async throws(KodaError) -> SyncPullResponseDTO
}

final class SyncRemoteDataSourceImpl: SyncRemoteDataSource, Sendable {
    // MARK: - Properties

    private let httpService: any HTTPService
    private let headerProvider: any HTTPHeaderProvider

    // MARK: - Lifecycle

    init(httpService: any HTTPService, headerProvider: any HTTPHeaderProvider) {
        self.httpService = httpService
        self.headerProvider = headerProvider
    }

    // MARK: - Public Methods

    func push(_ body: SyncPushRequestDTO) async throws(KodaError) -> SyncPushResponseDTO {
        try await httpService.execute(KodaAPI.syncPush(body, headerProvider: headerProvider))
    }

    func pull(cursor: Int64, limit: Int) async throws(KodaError) -> SyncPullResponseDTO {
        try await httpService.execute(KodaAPI.syncPull(cursor: cursor, limit: limit, headerProvider: headerProvider))
    }
}
