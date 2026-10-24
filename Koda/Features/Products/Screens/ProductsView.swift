import SwiftUI

/// Product catalog (pushed from Recetas · Productos).
struct ProductsView: View {
    @State private var viewModel: ProductsViewModel
    private let container: DependencyContainer

    init(viewModel: ProductsViewModel, container: DependencyContainer = .shared) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }

    var body: some View {
        List {
            if viewModel.state == .ready, viewModel.products.isEmpty {
                EmptyStateView(
                    titleKey: "products.empty.title",
                    messageKey: "products.empty.message",
                    actionKey: "products.new"
                ) {
                    Task { await viewModel.send(.newProduct) }
                }
                .listRowBackground(Color.clear)
            } else if viewModel.state == .ready, viewModel.sections.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
                    .listRowBackground(Color.clear)
            }
            ForEach(viewModel.sections, id: \.category) { section in
                Section {
                    ForEach(section.products) { product in
                        NavigationLink(value: AppRoute.product(id: product.id)) {
                            ProductRow(product: product, stores: viewModel.storeNames(for: product))
                        }
                        .swipeActions {
                            Button("products.delete", systemImage: "trash", role: .destructive) {
                                Task { await viewModel.send(.delete(product)) }
                            }
                        }
                        .contextMenu {
                            Button("products.delete", systemImage: "trash", role: .destructive) {
                                Task { await viewModel.send(.delete(product)) }
                            }
                        }
                    }
                } header: {
                    Text(section.category.titleKey)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KodaColor.background)
        .kodaAnimation(value: viewModel.products)
        .feedbackHaptic(viewModel.feedback)
        .searchable(text: $viewModel.searchText, prompt: Text("products.search"))
        .navigationTitle(Text("products.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("products.new", systemImage: "plus") {
                    Task { await viewModel.send(.newProduct) }
                }
                .accessibilityIdentifier("products-new")
            }
        }
        .toast($viewModel.toast)
        .sheet(item: $viewModel.presentedSheet) { _ in
            NavigationStack {
                ProductEditorView(
                    viewModel: Assembly.makeProductEditorViewModel(productID: nil, container: container),
                    presentation: .sheet
                )
            }
            .platformSheetSize(width: 520, height: 640)
        }
        .task { await viewModel.send(.appeared) }
    }
}

private struct ProductRow: View {
    let product: Product
    let stores: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: [product.emoji, product.name].compactMap { $0 }.joined(separator: " "))
                .font(KodaTypography.body.weight(.semibold))
            let detail = KodaFormat.joined([
                product.defaultUnit,
                stores.isEmpty ? nil : stores.joined(separator: ", "),
                product.pricePerKg.map { $0.formatted(.currency(code: "EUR")) + "/kg" },
            ])
            if !detail.isEmpty {
                Text(verbatim: detail)
                    .font(KodaTypography.footnote)
                    .foregroundStyle(KodaColor.textSecondary)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Products · iPhone") {
        ProductsPreviewFactory.makeProductsView()
            .kodaPreview()
    }

    #Preview("Products · empty") {
        ProductsPreviewFactory.makeProductsView(container: PreviewContainer.empty)
            .kodaPreview()
    }

    #Preview("Products · dark") {
        ProductsPreviewFactory.makeProductsView()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Products · Mac", traits: .fixedLayout(width: 1000, height: 700)) {
        ProductsPreviewFactory.makeProductsView()
            .kodaPreview()
    }
#endif
