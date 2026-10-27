import SwiftUI

/// Product detail (approved mockup "Detalle de producto"): hero with the cover or the emoji, recipes · stores · price,
/// "A la compra", photos, stores, the recipes that use it and its notes. The pencil opens the editor.
struct ProductDetailView: View {
    @State private var viewModel: ProductDetailViewModel
    private let container: DependencyContainer

    init(viewModel: ProductDetailViewModel, container: DependencyContainer = .shared) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .missing:
                ContentUnavailableView("product.missing", systemImage: "basket")
            case .loaded:
                if let detail = viewModel.detail {
                    ProductDetailContent(detail: detail, viewModel: viewModel)
                }
            }
        }
        .background(KodaColor.background)
        .feedbackHaptic(viewModel.feedback)
        .platformMacNavigationTitle(viewModel.detail?.product.name ?? "")
        .platformInlineNavigationTitle()
        .platformTransparentNavigationBar()
        .toolbar {
            if let product = viewModel.detail?.product {
                ToolbarItemGroup(placement: .primaryAction) {
                    if PlatformIdiom.current == .mac {
                        Button {
                            Task { await viewModel.send(.addPhotoTapped) }
                        } label: {
                            Label(
                                product.imagePath == nil ? "recipe.photos.add-cover" : "recipe.photos.add-photo-menu",
                                systemImage: "photo.badge.plus"
                            )
                        }
                        .accessibilityIdentifier("product-add-photo-toolbar")
                    }
                    Button {
                        Task { await viewModel.send(.edit) }
                    } label: {
                        Label("product.edit", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("product-edit")
                }
            }
        }
        .toast($viewModel.toast)
        .sheet(item: $viewModel.presentedSheet) { sheet in
            switch sheet {
            case .edit:
                NavigationStack {
                    ProductEditorView(
                        viewModel: Assembly.makeProductEditorViewModel(
                            productID: viewModel.productID,
                            container: container
                        ),
                        presentation: .sheet
                    )
                }
                .platformSheetSize(width: 520, height: 640)
            case .addPhoto(let asCover):
                AddRecipePhotoSheet(
                    title: viewModel.detail?.product.name ?? "",
                    asCover: asCover,
                    onPick: { data, asCover in Task { await viewModel.send(.addPhoto(data, asCover: asCover)) } },
                    onCancel: { Task { await viewModel.send(.dismissSheet) } }
                )
            }
        }
        .platformFullScreenCover(item: $viewModel.presentedViewer) { request in
            RecipePhotoViewer(
                title: viewModel.detail?.product.name ?? "",
                gallery: viewModel.detail?.gallery ?? [],
                bucket: .products,
                initialPath: request.initialPath,
                onSetCover: { item in Task { await viewModel.send(.setCover(item)) } },
                onDelete: { item in Task { await viewModel.send(.deletePhoto(item)) } },
                onClose: { Task { await viewModel.send(.dismissViewer) } }
            )
        }
        .task { await viewModel.send(.appeared) }
    }
}

/// The scrolling body of a loaded product.
private struct ProductDetailContent: View {
    let detail: ProductDetail
    let viewModel: ProductDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProductHero(product: detail.product) {
                    Task { await viewModel.send(.addPhotoTapped) }
                }
                VStack(alignment: .leading, spacing: KodaSpacing.l - 2) {
                    ProductStats(detail: detail)
                    ProductShoppingButton {
                        Task { await viewModel.send(.addToShopping) }
                    }
                    RecipePhotosSection(
                        gallery: detail.gallery,
                        bucket: .products,
                        emptyTitleKey: "product.photos.empty.title",
                        emptyMessageKey: "product.photos.empty.message",
                        isSaving: viewModel.photoSaveState == .saving,
                        onAdd: { Task { await viewModel.send(.addPhotoTapped) } },
                        onOpen: { item in Task { await viewModel.send(.openPhoto(item)) } },
                        onSetCover: { item in Task { await viewModel.send(.setCover(item)) } },
                        onDelete: { item in Task { await viewModel.send(.deletePhoto(item)) } },
                        onDrop: { data in
                            Task { await viewModel.send(.addPhoto(data, asCover: detail.product.imagePath == nil)) }
                        }
                    )
                    if !detail.stores.isEmpty {
                        ProductStoresSection(stores: detail.stores)
                    }
                    if !detail.usages.isEmpty {
                        ProductUsagesSection(usages: detail.usages)
                    }
                    if let notes = detail.product.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                        !notes.isEmpty
                    {
                        ProductNotesSection(notes: notes)
                    }
                }
                .padding(KodaSpacing.l - 4)
                .frame(maxWidth: KodaSize.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, KodaSpacing.xl * 2)
        }
        .ignoresSafeArea(edges: .top)
    }
}

/// Recipes · stores · price.
private struct ProductStats: View {
    let detail: ProductDetail
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: KodaSpacing.xs) {
            StatPill(value: "\(detail.usages.count)", captionKey: "product.stats.recipes")
            StatPill(value: "\(detail.stores.count)", captionKey: "product.stats.stores")
            StatPill(value: price.value, captionKey: price.captionKey)
        }
    }

    private var price: (value: String, captionKey: LocalizedStringKey) {
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2)).locale(locale)
        if let perKg = detail.product.pricePerKg {
            return (perKg.formatted(format), "product.stats.price-per-kg")
        }
        if let total = detail.product.priceTotal {
            return (total.formatted(format), "product.stats.price")
        }
        return ("—", "product.stats.no-price")
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Product detail · iPhone") {
        ProductsPreviewFactory.makeProductDetailView()
            .kodaPreview()
    }

    #Preview("Product detail · dark") {
        ProductsPreviewFactory.makeProductDetailView()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Product detail · empty sections") {
        ProductsPreviewFactory.makeProductDetailView(productID: PreviewDatabase.uuid(109))
            .kodaPreview()
    }

    #Preview("Product detail · missing") {
        ProductsPreviewFactory.makeProductDetailView(productID: UUID())
            .kodaPreview()
    }

    #Preview("Product detail · Mac", traits: .fixedLayout(width: 1000, height: 800)) {
        ProductsPreviewFactory.makeProductDetailView()
            .kodaPreview()
    }

    // The content alone renders on the first frame (the screen waits for its first database value).
    #Preview("Product detail · content") {
        NavigationStack {
            ProductDetailContent(
                detail: ProductsPreviewFactory.detail,
                viewModel: Assembly.makeProductDetailViewModel(
                    productID: ProductsPreviewFactory.detail.product.id,
                    container: PreviewContainer.populated
                )
            )
            .background(KodaColor.background)
        }
        .kodaPreview()
    }

    #Preview("Product detail · content · dark") {
        NavigationStack {
            ProductDetailContent(
                detail: ProductsPreviewFactory.detail,
                viewModel: Assembly.makeProductDetailViewModel(
                    productID: ProductsPreviewFactory.detail.product.id,
                    container: PreviewContainer.populated
                )
            )
            .background(KodaColor.background)
        }
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Product detail · content · Mac", traits: .fixedLayout(width: 1000, height: 1100)) {
        NavigationStack {
            ProductDetailContent(
                detail: ProductsPreviewFactory.detail,
                viewModel: Assembly.makeProductDetailViewModel(
                    productID: ProductsPreviewFactory.detail.product.id,
                    container: PreviewContainer.populated
                )
            )
            .background(KodaColor.background)
        }
        .kodaPreview()
    }
#endif
