import Foundation

/// The shared shopping list (local-first; `checked` and name/quantity resolve per field on the server).
protocol ShoppingRepository: Sendable {
    /// Live entries with their items and product/recipe names.
    func observeEntries() -> AsyncStream<[ShoppingEntry]>
    @discardableResult
    func addEntry(_ input: NewShoppingEntry) async throws(KodaError) -> ShoppingEntry
    @discardableResult
    func addRecipeEntry(_ input: NewRecipeShoppingEntry) async throws(KodaError) -> ShoppingEntry
    /// Ticks an entry; a recipe entry ticks all its items too.
    func setEntryChecked(id: UUID, isChecked: Bool) async throws(KodaError)
    func setItemChecked(id: UUID, isChecked: Bool) async throws(KodaError)
    func updateEntry(id: UUID, text: String?, quantity: Double?, unit: String?) async throws(KodaError)
    func removeEntry(id: UUID) async throws(KodaError)
    /// "Vaciar comprados". Returns how many entries were removed.
    @discardableResult
    func removeCheckedEntries() async throws(KodaError) -> Int
}
