import SwiftUI

/// Shopping previews over the seeded in-memory database, and sample rows for components.
@MainActor
enum ShoppingPreviewFactory {
    static func makeShoppingView(container: DependencyContainer = PreviewContainer.populated) -> some View {
        AppTabNavigationStack(tab: .shopping) {
            ShoppingView(viewModel: Assembly.makeShoppingViewModel(container: container))
        }
        .environment(AppRouter(selectedTab: .shopping))
    }

    static func makeGenerateShoppingViewModel(
        container: DependencyContainer = PreviewContainer.populated
    ) -> GenerateShoppingViewModel {
        Assembly.makeGenerateShoppingViewModel(container: container)
    }

    static let rows: [ShoppingRow] = [
        row(1, "Leche", .pending),
        row(2, "Huevos", .have),
        row(3, "Alitas de pollo", .frozen),
    ]

    static let recipeEntry = ShoppingEntry(
        id: PreviewDatabase.uuid(850),
        kind: .recipe,
        productID: nil,
        recipeID: PreviewDatabase.uuid(204),
        title: "Arroz a la cubana",
        emoji: nil,
        category: nil,
        quantity: 2,
        unit: "servings",
        status: .pending,
        source: .plan,
        position: 0,
        mealPlanEntryID: nil,
        items: []
    )

    private static func row(_ index: Int, _ title: String, _ status: ShoppingItemStatus) -> ShoppingRow {
        ShoppingRow(
            source: .entry(PreviewDatabase.uuid(index)),
            title: title,
            quantityText: "1 kg",
            status: status,
            category: .food,
            storeNames: ["Mercadona"],
            isText: false,
            recipeTitle: nil
        )
    }
}
