import Foundation

struct Store: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    /// `#RRGGBB`, when set.
    let color: String?
}

struct Product: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let category: ProductCategory
    let defaultUnit: String?
    let pricePerKg: Double?
    let priceTotal: Double?
    let servings: Double?
    let servingsPerWeek: Double?
    let notes: String?
    let emoji: String?
    let storeIDs: Set<UUID>
}

/// Values to create (`id == nil`) or update a product.
struct ProductInput: Sendable, Equatable {
    var id: UUID?
    var name: String
    var category: ProductCategory = .food
    var defaultUnit: String?
    var pricePerKg: Double?
    var priceTotal: Double?
    var servings: Double?
    var servingsPerWeek: Double?
    var notes: String?
    var emoji: String?
    /// `nil` leaves the store links untouched.
    var storeIDs: Set<UUID>?
}

struct StoreInput: Sendable, Equatable {
    var id: UUID?
    var name: String
    var color: String?
}
