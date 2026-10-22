import Foundation

/// Meal plan, drafts and consumption history.
protocol PlanningRepository: Sendable {
    /// Planned (non-draft) meals between two days, inclusive.
    func observeEntries(from: LocalDay, through: LocalDay) -> AsyncStream<[MealPlanEntry]>
    func observePendingDrafts() -> AsyncStream<[MealPlanDraft]>
    /// One-shot read of the planned (non-draft) meals between two days, inclusive.
    func entries(from: LocalDay, through: LocalDay) async throws(KodaError) -> [MealPlanEntry]
    @discardableResult
    func planMeal(_ input: NewMealPlanEntry) async throws(KodaError) -> MealPlanEntry
    func removeEntry(id: UUID) async throws(KodaError)
    @discardableResult
    func updateEntry(id: UUID, _ update: MealPlanEntryUpdate) async throws(KodaError) -> MealPlanEntry
    /// "No lo comimos": tombstones the entry's consumptions and sets `skipped_at`, in one transaction.
    func skipEntry(id: UUID, at date: Date) async throws(KodaError)
    @discardableResult
    func logConsumption(_ input: NewConsumption) async throws(KodaError) -> Consumption
    func removeConsumption(id: UUID) async throws(KodaError)
    /// Remote: `POST /drafts/:id/accept`. Returns the number of entries moved to the planning.
    func acceptDraft(id: UUID) async throws(KodaError) -> Int
    /// Remote: `POST /drafts/:id/discard`.
    func discardDraft(id: UUID) async throws(KodaError) -> Int
}
