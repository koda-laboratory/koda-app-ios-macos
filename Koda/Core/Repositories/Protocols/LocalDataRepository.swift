/// Whole-database operations tied to the session lifecycle.
protocol LocalDataRepository: Sendable {
    /// Wipes every product row, the outbox, the sync cursor and the cached `/me` (logout).
    func eraseAll() async throws(KodaError)
}
