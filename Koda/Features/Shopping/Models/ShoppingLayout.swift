import Foundation

/// How the pending products are grouped on screen.
enum ShoppingGrouping: String, Sendable, CaseIterable {
    case category
    case store
}

/// A product (or free text) row of the list, loose or inside a recipe entry.
struct ShoppingRow: Sendable, Equatable, Identifiable {
    enum Source: Sendable, Equatable {
        case entry(UUID)
        case item(entryID: UUID, itemID: UUID)
    }

    let source: Source
    let title: String
    let quantityText: String
    let status: ShoppingItemStatus
    let category: ProductCategory?
    let storeNames: [String]
    let isText: Bool
    /// The recipe entry title for products of a recipe ("Arroz a la cubana").
    let recipeTitle: String?
    /// The freezer bookkeeping the server keeps for this row, once synced.
    var frozenItem: FrozenItem?

    var id: String {
        switch source {
        case .entry(let id): id.uuidString
        case .item(_, let itemID): itemID.uuidString
        }
    }
}

/// Pending products grouped by category or store.
struct ShoppingGroup: Sendable, Equatable, Identifiable {
    let title: String
    let rows: [ShoppingRow]

    var id: String { title }
}

/// The shopping screen derived from the continuous list (approved mockup `Shopping`).
struct ShoppingLayout: Sendable, Equatable {
    /// Recipe entries still being bought, expandable item by item.
    let recipeEntries: [ShoppingEntry]
    let pendingGroups: [ShoppingGroup]
    /// "En el congelador": loose frozen products and frozen products of recipes.
    let frozenRows: [ShoppingRow]
    /// "Ya lo tenemos": products and completed recipe entries.
    let haveRows: [ShoppingRow]

    var pendingCount: Int {
        pendingGroups.reduce(0) { $0 + $1.rows.count } + recipeEntries.reduce(0) { $0 + $1.pendingItemCount }
    }

    var isEmpty: Bool {
        recipeEntries.isEmpty && pendingGroups.isEmpty && frozenRows.isEmpty && haveRows.isEmpty
    }

    init(
        entries: [ShoppingEntry],
        frozenItems: [FrozenItem],
        grouping: ShoppingGrouping,
        categoryTitle: (ProductCategory) -> String,
        otherTitle: String,
        noStoreTitle: String,
        quantity: (Double?, String?) -> String
    ) {
        let frozenByEntry = Dictionary(
            frozenItems.compactMap { item in item.shoppingEntryID.map { ($0, item) } },
            uniquingKeysWith: { first, _ in first }
        )
        let frozenByItem = Dictionary(
            frozenItems.compactMap { item in item.shoppingEntryItemID.map { ($0, item) } },
            uniquingKeysWith: { first, _ in first }
        )

        var recipes: [ShoppingEntry] = []
        var pending: [ShoppingRow] = []
        var frozen: [ShoppingRow] = []
        var have: [ShoppingRow] = []

        for entry in entries {
            if entry.kind == .recipe {
                if entry.status == .have {
                    have.append(Self.row(entry, quantity: quantity))
                } else {
                    recipes.append(entry)
                }
                for item in entry.items where item.status == .frozen {
                    var row = Self.row(item, entry: entry, quantity: quantity)
                    row.frozenItem = frozenByItem[item.id]
                    frozen.append(row)
                }
                continue
            }
            var row = Self.row(entry, quantity: quantity)
            switch entry.status {
            case .pending: pending.append(row)
            case .have: have.append(row)
            case .frozen:
                row.frozenItem = frozenByEntry[entry.id]
                frozen.append(row)
            }
        }

        var order: [String] = []
        var buckets: [String: [ShoppingRow]] = [:]
        let sortedPending: [ShoppingRow]
        switch grouping {
        case .category:
            let categoryOrder = ProductCategory.allCases
            sortedPending = pending.sorted { lhs, rhs in
                let lhsIndex =
                    lhs.isText ? categoryOrder.count : categoryOrder.firstIndex(of: lhs.category ?? .food) ?? 0
                let rhsIndex =
                    rhs.isText ? categoryOrder.count : categoryOrder.firstIndex(of: rhs.category ?? .food) ?? 0
                return lhsIndex < rhsIndex
            }
        case .store:
            sortedPending = pending.sorted { lhs, rhs in
                let lhsStore = lhs.storeNames.first ?? "\u{FFFF}"
                let rhsStore = rhs.storeNames.first ?? "\u{FFFF}"
                return lhsStore.localizedCaseInsensitiveCompare(rhsStore) == .orderedAscending
            }
        }
        for row in sortedPending {
            let key: String =
                switch grouping {
                case .category: row.isText ? otherTitle : categoryTitle(row.category ?? .food)
                case .store: row.storeNames.first ?? noStoreTitle
                }
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(row)
        }

        recipeEntries = recipes
        pendingGroups = order.map { ShoppingGroup(title: $0, rows: buckets[$0] ?? []) }
        frozenRows = frozen
        haveRows = have
    }

    private static func row(_ entry: ShoppingEntry, quantity: (Double?, String?) -> String) -> ShoppingRow {
        ShoppingRow(
            source: .entry(entry.id),
            title: entry.title,
            quantityText: entry.kind == .recipe ? "" : quantity(entry.quantity, entry.unit),
            status: entry.status,
            category: entry.category,
            storeNames: entry.storeNames,
            isText: entry.kind == .text,
            recipeTitle: nil
        )
    }

    private static func row(
        _ item: ShoppingEntryItem,
        entry: ShoppingEntry,
        quantity: (Double?, String?) -> String
    ) -> ShoppingRow {
        ShoppingRow(
            source: .item(entryID: entry.id, itemID: item.id),
            title: item.productName,
            quantityText: quantity(item.quantity, item.unit),
            status: item.status,
            category: item.category,
            storeNames: item.storeNames,
            isText: false,
            recipeTitle: entry.title
        )
    }
}
