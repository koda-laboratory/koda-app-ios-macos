import Foundation

enum ShoppingEntryKind: String, Sendable, Codable {
    case product
    case recipe
    case text
}

enum ShoppingEntrySource: String, Sendable, Codable {
    case manual
    case plan
    case siri
    case widget
    case mcp
}

/// The three states of a product on the list (PLAN.md 3.6): to buy, already at home (bought or we had it) and
/// in the freezer (not bought; a defrost reminder follows).
enum ShoppingItemStatus: String, Sendable, Codable, CaseIterable {
    case pending
    case have
    case frozen

    /// Tapping the row: have ↔ pending (a frozen item becomes have).
    var togglingHave: ShoppingItemStatus { self == .have ? .pending : .have }
    /// The snowflake: frozen ↔ pending (an item we have becomes frozen).
    var togglingFrozen: ShoppingItemStatus { self == .frozen ? .pending : .frozen }
}

/// One product of a recipe entry (flattened snapshot of the recipe and its sub-recipes).
struct ShoppingEntryItem: Sendable, Equatable, Identifiable {
    let id: UUID
    let productID: UUID
    let productName: String
    let productEmoji: String?
    let category: ProductCategory?
    let quantity: Double?
    let unit: String?
    let status: ShoppingItemStatus
    var storeNames: [String] = []

    var isChecked: Bool { status != .pending }
}

struct ShoppingEntry: Sendable, Equatable, Identifiable {
    let id: UUID
    let kind: ShoppingEntryKind
    let productID: UUID?
    let recipeID: UUID?
    /// Product name, recipe label ("Pollo al horno + Patatas al airfryer") or free text.
    let title: String
    let emoji: String?
    /// Category of the product (product entries only).
    let category: ProductCategory?
    let quantity: Double?
    let unit: String?
    let status: ShoppingItemStatus
    let source: ShoppingEntrySource
    let position: Int
    let mealPlanEntryID: UUID?
    /// Products of a recipe entry ("8 productos"), expandable to tick one by one.
    var items: [ShoppingEntryItem]
    /// Stores that sell the product (product entries only).
    var storeNames: [String] = []

    var isChecked: Bool { status != .pending }
    var checkedItemCount: Int { items.filter(\.isChecked).count }
    var pendingItemCount: Int { items.filter { $0.status == .pending }.count }
    var frozenItemCount: Int { items.filter { $0.status == .frozen }.count }
}

/// A product in the freezer and the meal it is for (`frozen_items`, maintained by the server).
struct FrozenItem: Sendable, Equatable, Identifiable {
    struct Meal: Sendable, Equatable {
        let entryID: UUID
        let day: LocalDay
        let slot: MealSlot
        let recipeID: UUID?
        let recipeName: String?
        let scheduledTime: LocalTime?
    }

    let id: UUID
    let productID: UUID
    let productName: String
    let shoppingEntryID: UUID?
    let shoppingEntryItemID: UUID?
    let meal: Meal?
    let frozenAt: Date?
    let defrostRemindAt: Date?

    /// "Descongelar hoy": from the reminder time until it is resolved.
    func isDue(now: Date) -> Bool {
        guard let defrostRemindAt else { return false }
        return defrostRemindAt <= now
    }
}

/// How the list groups entries: products by category, recipes together, free text last.
enum ShoppingListGroup: Hashable, Sendable {
    case category(ProductCategory)
    case recipes
    case other
}

struct ShoppingListSection: Sendable, Equatable, Identifiable {
    let group: ShoppingListGroup
    /// Pending first, then checked; each by position.
    let entries: [ShoppingEntry]

    var id: ShoppingListGroup { group }
}

struct ShoppingList: Sendable, Equatable {
    let sections: [ShoppingListSection]
    /// Every live entry, by position.
    let entries: [ShoppingEntry]

    var pendingCount: Int { sections.flatMap(\.entries).filter { !$0.isChecked }.count }
    var checkedCount: Int { sections.flatMap(\.entries).filter(\.isChecked).count }
    var isEmpty: Bool { sections.isEmpty }

    /// Products still to buy, counting each pending product of a recipe entry ("9 pendientes").
    var pendingProductCount: Int {
        entries.reduce(0) { total, entry in
            total + (entry.kind == .recipe ? entry.pendingItemCount : (entry.status == .pending ? 1 : 0))
        }
    }

    /// Pending products per store ("Mercadona 5 · Aldi 3"), most first. Products without a store are left out.
    var pendingCountByStore: [(store: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in entries {
            let stores: [[String]] =
                entry.kind == .recipe
                ? entry.items.filter { $0.status == .pending }.map(\.storeNames)
                : (entry.status == .pending ? [entry.storeNames] : [])
            for names in stores {
                guard let first = names.first else { continue }
                counts[first, default: 0] += 1
            }
        }
        return counts.map { (store: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.store < $1.store }
    }

    /// Groups entries by product category (in `ProductCategory` order), then recipes, then free text.
    init(entries: [ShoppingEntry]) {
        self.entries = entries
        var buckets: [ShoppingListGroup: [ShoppingEntry]] = [:]
        for entry in entries {
            buckets[Self.group(of: entry), default: []].append(entry)
        }
        let order = ProductCategory.allCases.map(ShoppingListGroup.category) + [.recipes, .other]
        self.sections = order.compactMap { group in
            guard let entries = buckets[group], !entries.isEmpty else { return nil }
            let sorted = entries.sorted { lhs, rhs in
                if lhs.isChecked != rhs.isChecked { return !lhs.isChecked }
                return lhs.position < rhs.position
            }
            return ShoppingListSection(group: group, entries: sorted)
        }
    }

    private static func group(of entry: ShoppingEntry) -> ShoppingListGroup {
        switch entry.kind {
        case .product: .category(entry.category ?? .food)
        case .recipe: .recipes
        case .text: .other
        }
    }
}

/// A product or a free text to add to the list.
struct NewShoppingEntry: Sendable, Equatable {
    enum Item: Sendable, Equatable {
        case product(UUID)
        case text(String)
    }

    var item: Item
    var quantity: Double?
    var unit: String?
    var source: ShoppingEntrySource = .manual
}

/// A recipe entry with its flattened products, written in one transaction.
struct NewRecipeShoppingEntry: Sendable, Equatable {
    struct Item: Sendable, Equatable {
        let productID: UUID
        let quantity: Double?
        let unit: String?
    }

    var recipeID: UUID
    var label: String
    var servings: Double?
    var items: [Item]
    var source: ShoppingEntrySource = .manual
    var mealPlanEntryID: UUID?
}
