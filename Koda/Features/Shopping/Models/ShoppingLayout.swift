import Foundation

/// A product (or free text) row of the list: loose, inside a recipe entry, or shared by several entries.
struct ShoppingRow: Sendable, Equatable, Identifiable {
    enum Source: Sendable, Equatable {
        case entry(UUID)
        case item(entryID: UUID, itemID: UUID)
        /// One product that several entries need ("Huevos" in two recipes), shown once.
        case shared(productID: UUID)
    }

    /// One of the entries behind a shared row, with its own status.
    struct Occurrence: Sendable, Equatable {
        let source: Source
        let status: ShoppingItemStatus
    }

    let source: Source
    let title: String
    let quantityText: String
    let status: ShoppingItemStatus
    let category: ProductCategory?
    let storeNames: [String]
    let isText: Bool
    /// The recipe entry title for products of a recipe ("Arroz a la cubana"); for a shared row, every recipe
    /// that needs it.
    let recipeTitle: String?
    /// The freezer bookkeeping the server keeps for this row, once synced.
    var frozenItem: FrozenItem?
    /// For a shared row: the loose entries and recipe items it stands for.
    var occurrences: [Occurrence] = []

    var id: String {
        switch source {
        case .entry(let id): id.uuidString
        case .item(_, let itemID): itemID.uuidString
        case .shared(let productID): "shared-\(productID.uuidString)"
        }
    }

    /// A stand-in for a shared product's freezer row while its occurrences are collected.
    fileprivate static func placeholder(productID: UUID) -> ShoppingRow {
        ShoppingRow(
            source: .shared(productID: productID),
            title: "",
            quantityText: "",
            status: .frozen,
            category: nil,
            storeNames: [],
            isText: false,
            recipeTitle: nil
        )
    }

    /// The sources a status change applies to: a shared row changes only the occurrences that share its
    /// current state (marking "Huevos" as bought leaves a frozen occurrence in the freezer).
    var targets: [Source] {
        guard case .shared = source else { return [source] }
        return occurrences.filter { $0.status == status }.map(\.source)
    }
}

/// Pending products of one category.
struct ShoppingGroup: Sendable, Equatable, Identifiable {
    let title: String
    let rows: [ShoppingRow]

    var id: String { title }
}

/// The shopping screen derived from the continuous list (approved mockup `Shopping`).
struct ShoppingLayout: Sendable, Equatable {
    /// "En varias recetas": products more than one entry needs, ticked once for all of them.
    let sharedRows: [ShoppingRow]
    /// Recipe entries still being bought (without their shared products), expandable item by item. An entry whose
    /// products are all shared has no items here but keeps its card.
    let recipeEntries: [ShoppingEntry]
    let pendingGroups: [ShoppingGroup]
    /// "En el congelador": loose frozen products and frozen products of recipes.
    let frozenRows: [ShoppingRow]
    /// "Ya lo tenemos": products and completed recipe entries.
    let haveRows: [ShoppingRow]

    var pendingCount: Int {
        pendingGroups.reduce(0) { $0 + $1.rows.count }
            + recipeEntries.reduce(0) { $0 + $1.pendingItemCount }
            + sharedRows.filter { $0.status == .pending }.count
    }

    var isEmpty: Bool {
        sharedRows.isEmpty && recipeEntries.isEmpty && pendingGroups.isEmpty && frozenRows.isEmpty
            && haveRows.isEmpty
    }

    init(
        entries: [ShoppingEntry],
        frozenItems: [FrozenItem],
        categoryTitle: (ProductCategory) -> String,
        otherTitle: String,
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
        let shared = Self.sharedRows(in: entries, quantity: quantity)
        let sharedProductIDs = Set(
            shared.compactMap { row -> UUID? in
                guard case .shared(let productID) = row.source else { return nil }
                return productID
            }
        )

        var recipes: [ShoppingEntry] = []
        var pending: [ShoppingRow] = []
        var frozen: [ShoppingRow] = []
        /// Frozen occurrences of shared products, merged into one freezer row per product below.
        var sharedFrozen: [UUID: [ShoppingRow]] = [:]
        var have: [ShoppingRow] = []
        func addFrozen(_ row: ShoppingRow, productID: UUID?) {
            guard let productID, sharedProductIDs.contains(productID) else {
                frozen.append(row)
                return
            }
            if sharedFrozen[productID] == nil {
                // Placeholder keeping the product's place in the freezer list.
                frozen.append(ShoppingRow.placeholder(productID: productID))
            }
            sharedFrozen[productID, default: []].append(row)
        }

        for entry in entries {
            if entry.kind == .recipe {
                for item in entry.items where item.status == .frozen {
                    var row = Self.row(item, entry: entry, quantity: quantity)
                    row.frozenItem = frozenByItem[item.id]
                    addFrozen(row, productID: item.productID)
                }
                if entry.status == .have {
                    have.append(Self.row(entry, quantity: quantity))
                    continue
                }
                // The card stays even when every product moved to "En varias recetas": it is the only place to
                // remove the recipe (for example one added twice by mistake).
                var visible = entry
                visible.items = entry.items.filter { !sharedProductIDs.contains($0.productID) }
                recipes.append(visible)
                continue
            }
            var row = Self.row(entry, quantity: quantity)
            if entry.status == .frozen {
                row.frozenItem = frozenByEntry[entry.id]
                addFrozen(row, productID: entry.productID)
                continue
            }
            if let productID = entry.productID, sharedProductIDs.contains(productID) { continue }
            switch entry.status {
            case .pending: pending.append(row)
            case .have: have.append(row)
            case .frozen: break
            }
        }

        let categoryOrder = ProductCategory.allCases
        let sortedPending = pending.sorted { lhs, rhs in
            let lhsIndex = lhs.isText ? categoryOrder.count : categoryOrder.firstIndex(of: lhs.category ?? .food) ?? 0
            let rhsIndex = rhs.isText ? categoryOrder.count : categoryOrder.firstIndex(of: rhs.category ?? .food) ?? 0
            return lhsIndex < rhsIndex
        }
        var order: [String] = []
        var buckets: [String: [ShoppingRow]] = [:]
        for row in sortedPending {
            let key = row.isText ? otherTitle : categoryTitle(row.category ?? .food)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(row)
        }

        sharedRows = shared
        recipeEntries = recipes
        pendingGroups = order.map { ShoppingGroup(title: $0, rows: buckets[$0] ?? []) }
        frozenRows = frozen.map { row in
            guard case .shared(let productID) = row.source, let rows = sharedFrozen[productID] else { return row }
            return Self.mergedFrozenRow(productID: productID, rows: rows)
        }
        haveRows = have
    }

    /// Products that two or more entries need: loose product entries and the products of recipe entries still
    /// being bought. The row stays in this card in every state; its status is "to buy" while any occurrence is,
    /// then "frozen" while any is in the freezer, then "at home".
    private static func sharedRows(
        in entries: [ShoppingEntry],
        quantity: (Double?, String?) -> String
    ) -> [ShoppingRow] {
        struct Occurrence {
            let source: ShoppingRow.Source
            let entryID: UUID
            let name: String
            let category: ProductCategory?
            let storeNames: [String]
            let quantity: Double?
            let unit: String?
            let status: ShoppingItemStatus
            let recipeTitle: String?
        }

        var order: [UUID] = []
        var byProduct: [UUID: [Occurrence]] = [:]
        func add(_ productID: UUID, _ occurrence: Occurrence) {
            if byProduct[productID] == nil { order.append(productID) }
            byProduct[productID, default: []].append(occurrence)
        }
        for entry in entries {
            switch entry.kind {
            case .product:
                guard let productID = entry.productID else { continue }
                add(
                    productID,
                    Occurrence(
                        source: .entry(entry.id),
                        entryID: entry.id,
                        name: entry.title,
                        category: entry.category,
                        storeNames: entry.storeNames,
                        quantity: entry.quantity,
                        unit: entry.unit,
                        status: entry.status,
                        recipeTitle: nil
                    )
                )
            case .recipe where entry.status != .have:
                for item in entry.items {
                    add(
                        item.productID,
                        Occurrence(
                            source: .item(entryID: entry.id, itemID: item.id),
                            entryID: entry.id,
                            name: item.productName,
                            category: item.category,
                            storeNames: item.storeNames,
                            quantity: item.quantity,
                            unit: item.unit,
                            status: item.status,
                            recipeTitle: entry.title
                        )
                    )
                }
            case .recipe, .text:
                continue
            }
        }

        return order.compactMap { productID -> ShoppingRow? in
            let all = byProduct[productID] ?? []
            guard Set(all.map(\.entryID)).count > 1 else { return nil }
            guard let first = all.first else { return nil }
            let status: ShoppingItemStatus =
                if all.contains(where: { $0.status == .pending }) {
                    .pending
                } else if all.contains(where: { $0.status == .frozen }) {
                    .frozen
                } else {
                    .have
                }
            let units = Set(all.map(\.unit))
            let quantities = all.compactMap(\.quantity)
            let total: Double? = units.count == 1 && quantities.count == all.count ? quantities.reduce(0, +) : nil
            var titles: [String] = []
            for title in all.compactMap(\.recipeTitle) where !titles.contains(title) {
                titles.append(title)
            }
            return ShoppingRow(
                source: .shared(productID: productID),
                title: first.name,
                quantityText: total == nil ? "" : quantity(total, first.unit),
                status: status,
                category: first.category,
                storeNames: first.storeNames,
                isText: false,
                recipeTitle: titles.isEmpty ? nil : titles.joined(separator: " · "),
                occurrences: all.map { ShoppingRow.Occurrence(source: $0.source, status: $0.status) }
            )
        }
    }

    /// One freezer row for a product several entries froze ("Huevos" for two recipes): every recipe it is for, and
    /// the earliest defrost reminder. Removing it from the freezer applies to every occurrence.
    private static func mergedFrozenRow(productID: UUID, rows: [ShoppingRow]) -> ShoppingRow {
        guard let first = rows.first, rows.count > 1 else { return rows[0] }
        var titles: [String] = []
        for title in rows.compactMap(\.recipeTitle) where !titles.contains(title) {
            titles.append(title)
        }
        let earliest = rows.compactMap(\.frozenItem).min { lhs, rhs in
            (lhs.defrostRemindAt ?? .distantFuture) < (rhs.defrostRemindAt ?? .distantFuture)
        }
        return ShoppingRow(
            source: .shared(productID: productID),
            title: first.title,
            quantityText: "",
            status: .frozen,
            category: first.category,
            storeNames: first.storeNames,
            isText: false,
            recipeTitle: titles.isEmpty ? nil : titles.joined(separator: " · "),
            frozenItem: earliest,
            occurrences: rows.map { ShoppingRow.Occurrence(source: $0.source, status: .frozen) }
        )
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
