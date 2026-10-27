import SwiftUI

/// Products previews over the seeded in-memory database.
@MainActor
enum ProductsPreviewFactory {
    static func makeProductsView(container: DependencyContainer = PreviewContainer.populated) -> some View {
        NavigationStack {
            ProductsView(viewModel: Assembly.makeProductsViewModel(container: container), container: container)
        }
        .environment(AppRouter(selectedTab: .recipes))
    }

    static func makeProductEditorView(
        productID: UUID? = PreviewDatabase.uuid(104),
        container: DependencyContainer = PreviewContainer.populated
    ) -> some View {
        ProductEditorView(
            viewModel: Assembly.makeProductEditorViewModel(productID: productID, container: container),
            presentation: productID == nil ? .sheet : .push
        )
    }

    static func makeProductDetailView(
        productID: UUID = PreviewDatabase.uuid(104),
        container: DependencyContainer = PreviewContainer.populated
    ) -> some View {
        NavigationStack {
            ProductDetailView(
                viewModel: Assembly.makeProductDetailViewModel(productID: productID, container: container),
                container: container
            )
        }
        .environment(AppRouter(selectedTab: .recipes))
    }

    static let product = Product(
        id: PreviewDatabase.uuid(106),
        name: "Huevos",
        category: .food,
        defaultUnit: "uds",
        pricePerKg: nil,
        priceTotal: 2.4,
        servings: nil,
        servingsPerWeek: nil,
        notes: nil,
        emoji: "🥚",
        storeIDs: []
    )

    static let productWithoutEmoji = Product(
        id: PreviewDatabase.uuid(105),
        name: "Arroz",
        category: .food,
        defaultUnit: "g",
        pricePerKg: 1.35,
        priceTotal: nil,
        servings: nil,
        servingsPerWeek: nil,
        notes: nil,
        emoji: nil,
        storeIDs: []
    )

    static let stores = [
        Store(id: PreviewDatabase.uuid(301), name: "Mercadona", color: nil),
        Store(id: PreviewDatabase.uuid(302), name: "Aldi", color: nil),
        Store(id: PreviewDatabase.uuid(303), name: "Ahorramas", color: nil),
    ]

    static let usages = [
        ProductRecipeUsage(
            recipeID: PreviewDatabase.uuid(205),
            recipeName: "Paella de carrilleras",
            quantity: 500,
            unit: "g",
            timeMinutes: 90
        ),
        ProductRecipeUsage(
            recipeID: PreviewDatabase.uuid(206),
            recipeName: "Estofado de ternera",
            quantity: 600,
            unit: "g",
            timeMinutes: 120
        ),
    ]

    /// A filled detail without the database, for previews that must render on the first frame.
    static let detail = ProductDetail(
        product: Product(
            id: PreviewDatabase.uuid(104),
            name: "Aguja de ternera",
            category: .food,
            defaultUnit: "kg",
            pricePerKg: 12.9,
            priceTotal: nil,
            servings: nil,
            servingsPerWeek: nil,
            notes: "La de Mercadona viene en bandeja de 600 g; pedirla al carnicero en dados.",
            emoji: "🥩",
            storeIDs: Set(stores.map(\.id))
        ),
        stores: stores,
        photos: [],
        usages: usages
    )
}
