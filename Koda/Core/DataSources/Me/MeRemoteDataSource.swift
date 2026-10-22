/// `GET /me` of the `api` Edge Function.
protocol MeRemoteDataSource: Sendable {
    func fetchMe() async throws(KodaError) -> MeResponseDTO
    func updateSettings(householdID: String, _ body: HouseholdSettingsRequestDTO) async throws(KodaError)
        -> MeHouseholdDTO
}

final class MeRemoteDataSourceImpl: MeRemoteDataSource, Sendable {
    private let httpService: any HTTPService
    private let headerProvider: any HTTPHeaderProvider

    init(httpService: any HTTPService, headerProvider: any HTTPHeaderProvider) {
        self.httpService = httpService
        self.headerProvider = headerProvider
    }

    func fetchMe() async throws(KodaError) -> MeResponseDTO {
        try await httpService.execute(KodaAPI.me(headerProvider: headerProvider))
    }

    func updateSettings(householdID: String, _ body: HouseholdSettingsRequestDTO) async throws(KodaError)
        -> MeHouseholdDTO
    {
        try await httpService.execute(
            KodaAPI.updateHouseholdSettings(householdID: householdID, body, headerProvider: headerProvider)
        )
    }
}
