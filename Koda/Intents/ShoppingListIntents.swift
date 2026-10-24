import AppIntents
import Foundation

/// "Enséñame la lista de la compra de Koda": the pending products as an interactive card; each one can be ticked
/// from the card itself.
struct ShowShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.show-shopping.title"
    static let description = IntentDescription("intent.show-shopping.description")
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Dependency var services: IntentServices

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let pending = ShoppingSnippetRow.pending(in: await services.shoppingList())
        let dialog: IntentDialog =
            pending.isEmpty ? "intent.show-shopping.empty" : "intent.show-shopping.dialog \(pending.count)"
        return .result(dialog: dialog, snippetIntent: ShoppingListSnippetIntent())
    }
}

/// The live card of `ShowShoppingListIntent`: re-run by the system after each tick, so it only reads.
struct ShoppingListSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "intent.show-shopping.title"
    static let isDiscoverable = false

    @Dependency var services: IntentServices

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let rows = ShoppingSnippetRow.pending(in: await services.shoppingList())
        return .result(
            view: ShoppingListSnippetView(rows: Array(rows.prefix(ShoppingSnippetRow.limit)), total: rows.count)
        )
    }
}

/// A tick from the shopping card: marks the product as "ya lo tenemos" (`have`).
struct MarkShoppingRowAsHaveIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.mark-have.title"
    static let isDiscoverable = false
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "intent.mark-have.row")
    var rowID: String

    @Parameter(title: "intent.mark-have.is-item")
    var isRecipeItem: Bool

    @Dependency var services: IntentServices

    init() {}

    init(row: ShoppingSnippetRow) {
        rowID = row.id.uuidString
        isRecipeItem = row.isRecipeItem
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: rowID) else { return .result() }
        if isRecipeItem {
            try await services.setItemStatus.execute(itemID: id, status: .have)
        } else {
            try await services.setEntryStatus.execute(entryID: id, status: .have)
        }
        return .result()
    }
}

/// A pending product of the list, loose or inside a recipe entry.
struct ShoppingSnippetRow: Sendable, Equatable, Identifiable {
    static let limit = 8

    let id: UUID
    let title: String
    let detail: String?
    let isRecipeItem: Bool

    static func pending(in list: ShoppingList?) -> [ShoppingSnippetRow] {
        guard let list else { return [] }
        var rows: [ShoppingSnippetRow] = []
        for entry in list.entries {
            switch entry.kind {
            case .product, .text:
                guard entry.status == .pending else { continue }
                rows.append(ShoppingSnippetRow(id: entry.id, title: entry.title, detail: nil, isRecipeItem: false))
            case .recipe:
                guard entry.status != .have else { continue }
                for item in entry.items where item.status == .pending {
                    rows.append(
                        ShoppingSnippetRow(
                            id: item.id,
                            title: item.productName,
                            detail: entry.title,
                            isRecipeItem: true
                        )
                    )
                }
            }
        }
        return rows
    }
}
