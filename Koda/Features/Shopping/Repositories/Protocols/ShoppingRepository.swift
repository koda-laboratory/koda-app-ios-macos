import Foundation

/// The shared shopping list (local-first; `checked` and name/quantity resolve per field on the server).
protocol ShoppingRepository: Sendable {
    /// Live entries with their items and product/recipe names.
    func observeEntries() -> AsyncStream<[ShoppingEntry]>
    /// Unresolved `frozen_items` with their product and meal.
    func observeFrozenItems() -> AsyncStream<[FrozenItem]>
    /// Planned meals whose recipe is already on the list (`shopping_entries.meal_plan_entry_id`).
    func mealPlanEntryIDsOnList() async throws(KodaError) -> Set<UUID>
    @discardableResult
    func addEntry(_ input: NewShoppingEntry) async throws(KodaError) -> ShoppingEntry
    /// Idempotent per planned meal: when `mealPlanEntryID` is already on the list, returns that entry.
    @discardableResult
    func addRecipeEntry(_ input: NewRecipeShoppingEntry) async throws(KodaError) -> ShoppingEntry
    /// Ticks an entry; a recipe entry ticks all its items too.
    func setEntryChecked(id: UUID, isChecked: Bool) async throws(KodaError)
    func setItemChecked(id: UUID, isChecked: Bool) async throws(KodaError)
    /// Three-state change of a product, text or recipe entry (a recipe entry applies it to all its items).
    func setEntryStatus(id: UUID, status: ShoppingItemStatus) async throws(KodaError)
    /// Three-state change of one product of a recipe entry; the entry becomes `have` when every item is.
    func setItemStatus(id: UUID, status: ShoppingItemStatus) async throws(KodaError)
    /// "Hecho" on a defrost reminder.
    func resolveFrozenItem(id: UUID, at date: Date) async throws(KodaError)
    func updateEntry(id: UUID, text: String?, quantity: Double?, unit: String?) async throws(KodaError)
    func removeEntry(id: UUID) async throws(KodaError)
    /// "Vaciar" on "Ya lo tenemos": removes the entries in `have` (frozen ones stay). Returns how many.
    @discardableResult
    func removeCheckedEntries() async throws(KodaError) -> Int
}
