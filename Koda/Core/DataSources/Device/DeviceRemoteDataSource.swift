/// `PUT /devices` and `DELETE /devices/:id` of the `api` Edge Function.
protocol DeviceRemoteDataSource: Sendable {
    func register(_ body: DeviceRegistrationRequestDTO) async throws(KodaError)
    func unregister(id: String) async throws(KodaError)
}

final class DeviceRemoteDataSourceImpl: DeviceRemoteDataSource, Sendable {
    private let httpService: any HTTPService
    private let headerProvider: any HTTPHeaderProvider

    init(httpService: any HTTPService, headerProvider: any HTTPHeaderProvider) {
        self.httpService = httpService
        self.headerProvider = headerProvider
    }

    func register(_ body: DeviceRegistrationRequestDTO) async throws(KodaError) {
        try await httpService.execute(KodaAPI.registerDevice(body, headerProvider: headerProvider))
    }

    func unregister(id: String) async throws(KodaError) {
        try await httpService.execute(KodaAPI.unregisterDevice(id: id, headerProvider: headerProvider))
    }
}
