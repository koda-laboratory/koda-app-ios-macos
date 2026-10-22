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
}
