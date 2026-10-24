import Foundation

/// Image objects in Supabase Storage (`recipe-images`), with the user's JWT.
protocol RecipeImageRemoteDataSource: Sendable {
    func upload(_ data: Data, path: String, contentType: String) async throws(KodaError)
    func download(path: String) async throws(KodaError) -> Data
}

final class RecipeImageRemoteDataSourceImpl: RecipeImageRemoteDataSource, Sendable {
    private let httpService: any HTTPService
    private let headerProvider: any HTTPHeaderProvider

    init(httpService: any HTTPService, headerProvider: any HTTPHeaderProvider) {
        self.httpService = httpService
        self.headerProvider = headerProvider
    }

    func upload(_ data: Data, path: String, contentType: String) async throws(KodaError) {
        try await httpService.execute(
            StorageAPI.upload(path: path, data: data, contentType: contentType, headerProvider: headerProvider)
        )
    }

    func download(path: String) async throws(KodaError) -> Data {
        try await httpService.execute(StorageAPI.download(path: path, headerProvider: headerProvider))
    }
}
