/// Server-side planning operations of the `api` Edge Function (drafts are accepted or discarded atomically on
/// the server; the result reaches the database through the next pull).
protocol PlanningRemoteDataSource: Sendable {
    func acceptDraft(id: String) async throws(KodaError) -> DraftActionResponseDTO
    func discardDraft(id: String) async throws(KodaError) -> DraftActionResponseDTO
}

final class PlanningRemoteDataSourceImpl: PlanningRemoteDataSource, Sendable {
    private let httpService: any HTTPService
    private let headerProvider: any HTTPHeaderProvider

    init(httpService: any HTTPService, headerProvider: any HTTPHeaderProvider) {
        self.httpService = httpService
        self.headerProvider = headerProvider
    }

    func acceptDraft(id: String) async throws(KodaError) -> DraftActionResponseDTO {
        try await httpService.execute(KodaAPI.acceptDraft(id: id, headerProvider: headerProvider))
    }

    func discardDraft(id: String) async throws(KodaError) -> DraftActionResponseDTO {
        try await httpService.execute(KodaAPI.discardDraft(id: id, headerProvider: headerProvider))
    }
}
