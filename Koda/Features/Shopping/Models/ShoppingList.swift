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

/// One product of a recipe entry (flattened snapshot of the recipe and its sub-recipes).
struct ShoppingEntryItem: Sendable, Equatable, Identifiable {
    let id: UUID
    let productID: UUID
    let productName: String
    let productEmoji: String?
    let category: ProductCategory?
    let quantity: Double?
    let unit: String?
    let isChecked: Bool
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
    let isChecked: Bool
    let source: ShoppingEntrySource
    let position: Int
    let mealPlanEntryID: UUID?
    /// Products of a recipe entry ("8 productos"), expandable to tick one by one.
    let items: [ShoppingEntryItem]

    var checkedItemCount: Int { items.filter(\.isChecked).count }
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

    var pendingCount: Int { sections.flatMap(\.entries).filter { !$0.isChecked }.count }
    var checkedCount: Int { sections.flatMap(\.entries).filter(\.isChecked).count }
    var isEmpty: Bool { sections.isEmpty }

    /// Groups entries by product category (in `ProductCategory` order), then recipes, then free text.
    init(entries: [ShoppingEntry]) {
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
