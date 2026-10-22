/// The signed-in user's profile and household (`GET /me`), cached in the local database.
protocol MeRepository: Sendable {
    /// Fetches `/me` and replaces the cache. Fails when the user belongs to no household.
    @discardableResult
    func refresh() async throws(KodaError) -> HouseholdContext
    func cached() async throws(KodaError) -> HouseholdContext?
    func observe() -> AsyncStream<HouseholdContext?>
}
