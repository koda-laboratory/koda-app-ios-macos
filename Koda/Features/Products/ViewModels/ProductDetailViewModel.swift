import Foundation
import Observation

enum ProductDetailState: Sendable, Equatable {
    case loading
    case loaded
    /// Deleted here or on another device.
    case missing
}

enum ProductDetailSheet: Sendable, Equatable, Identifiable {
    case edit
    /// "Añadir foto", with "Usar como portada" preselected when the product has no cover yet.
    case addPhoto(asCover: Bool)

    var id: String {
        switch self {
        case .edit: "edit"
        case .addPhoto: "add-photo"
        }
    }
}

enum ProductDetailIntent: Sendable {
    case appeared
    case edit
    case dismissSheet
    case addToShopping
    case addPhotoTapped
    /// A picked, captured or dropped image.
    case addPhoto(Data, asCover: Bool)
    case setCover(RecipeGalleryItem)
    case deletePhoto(RecipeGalleryItem)
    case openPhoto(RecipeGalleryItem)
    case dismissViewer
}

/// Product detail (approved mockup "Detalle de producto"): cover and gallery, how many recipes and stores, price,
/// "A la compra", its stores, the recipes that use it and its notes.
@MainActor
@Observable
final class ProductDetailViewModel: MVIViewModel {
    /// The use cases the detail depends on.
    struct UseCases {
        let observeDetail: any ObserveProductDetailUseCase
        let addShoppingEntry: any AddShoppingEntryUseCase
        let addPhoto: any AddProductPhotoUseCase
        let setCover: any SetProductCoverUseCase
        let deletePhoto: any DeleteProductPhotoUseCase
    }

    // MARK: - Properties

    let productID: UUID
    private(set) var state = ProductDetailState.loading
    private(set) var detail: ProductDetail?
    private(set) var photoSaveState = RecipePhotoSaveState.idle
    var presentedSheet: ProductDetailSheet?
    var presentedViewer: RecipePhotoViewerRequest?
    var toast: Toast?
    private(set) var feedback: FeedbackEvent?

    @ObservationIgnored private let useCases: UseCases
    @ObservationIgnored private var observation: Task<Void, Never>?

    // MARK: - Lifecycle

    init(productID: UUID, useCases: UseCases) {
        self.productID = productID
        self.useCases = useCases
    }

    deinit {
        observation?.cancel()
    }

    // MARK: - Intents

    func send(_ intent: ProductDetailIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        case .edit:
            presentedSheet = .edit
        case .dismissSheet:
            presentedSheet = nil
        case .addToShopping:
            await addToShopping()
        case .addPhotoTapped:
            presentedSheet = .addPhoto(asCover: detail?.product.imagePath == nil)
        case .addPhoto(let data, let asCover):
            presentedSheet = nil
            await addPhoto(data, asCover: asCover)
        case .setCover(let item):
            await setCover(item)
        case .deletePhoto(let item):
            await deletePhoto(item)
        case .openPhoto(let item):
            presentedViewer = RecipePhotoViewerRequest(initialPath: item.path)
        case .dismissViewer:
            presentedViewer = nil
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observation == nil else { return }
        let details = useCases.observeDetail.execute(productID: productID)
        observation = Task { [weak self] in
            for await detail in details {
                self?.apply(detail)
            }
        }
    }

    private func apply(_ detail: ProductDetail?) {
        self.detail = detail
        state = detail == nil ? .missing : .loaded
    }

    private func addToShopping() async {
        do {
            try await useCases.addShoppingEntry.execute(NewShoppingEntry(item: .product(productID)))
            feedback = FeedbackEvent(.added)
            toast = Toast(messageKey: "product.toast.added-to-shopping")
        } catch {
            toast = .error(error)
        }
    }

    private func addPhoto(_ data: Data, asCover: Bool) async {
        guard photoSaveState == .idle else { return }
        photoSaveState = .saving
        do {
            try await useCases.addPhoto.execute(productID: productID, imageData: data, asCover: asCover)
            feedback = FeedbackEvent(.added)
        } catch {
            toast = .error(error)
        }
        photoSaveState = .idle
    }

    private func setCover(_ item: RecipeGalleryItem) async {
        do {
            try await useCases.setCover.execute(productID: productID, item: item)
            toast = Toast(messageKey: "recipe.photos.toast.cover")
        } catch {
            toast = .error(error)
        }
    }

    private func deletePhoto(_ item: RecipeGalleryItem) async {
        do {
            try await useCases.deletePhoto.execute(productID: productID, item: item)
            feedback = FeedbackEvent(.removed)
            // The viewer closes when its last image goes.
            if detail?.gallery.count ?? 0 <= 1 { presentedViewer = nil }
        } catch {
            toast = .error(error)
        }
    }
}
