import Foundation

/// The signed-in user's profile and household (`GET /me`), cached in the local database.
protocol MeRepository: Sendable {
    /// Fetches `/me` and replaces the cache. Fails when the user belongs to no household.
    @discardableResult
    func refresh() async throws(KodaError) -> HouseholdContext
    func cached() async throws(KodaError) -> HouseholdContext?
    func observe() -> AsyncStream<HouseholdContext?>
    /// Remote `PATCH /households/:id/settings`, then updates the cache. Needs the network.
    @discardableResult
    func updateSettings(householdID: UUID, settings: HouseholdSettings) async throws(KodaError) -> HouseholdContext
}
