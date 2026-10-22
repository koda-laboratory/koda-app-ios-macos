final class LocalDataRepositoryImpl: LocalDataRepository, Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func eraseAll() async throws(KodaError) {
        try await database.eraseAllData()
    }
}
