import Foundation
import GRDB
import Testing

@testable import Koda

@Suite("Product photos and detail")
struct ProductPhotoTests {
    @Test("Adding a photo as cover writes the file, the photo, the cover and a product-images upload in one step")
    func addAsCover() async throws {
        let environment = try await FeatureEnvironment.make()
        let product = try await environment.product("Aguja de ternera")
        let before = try await environment.outbox().count

        try await environment.addProductPhoto.execute(
            productID: product.id,
            imageData: try TestImages.png(width: 3200, height: 2400),
            asCover: true
        )

        let path = try #require(environment.imageFiles.paths(in: .products).first)
        #expect(environment.imageFiles.paths(in: .recipes).isEmpty)
        #expect(path.hasPrefix("\(TestDatabase.householdID)/\(product.id.lowercasedString)/"))
        let stored = try await TestDatabase.string(
            "SELECT image_path || '|' || image_source FROM products WHERE id = '\(product.id.lowercasedString)'",
            in: environment.database
        )
        #expect(stored == "\(path)|photo")
        let size = try await TestDatabase.string(
            "SELECT width || 'x' || height FROM product_photos",
            in: environment.database
        )
        #expect(size == "1600x1200")
        let bucket = try await TestDatabase.string("SELECT bucket FROM pending_image_uploads", in: environment.database)
        #expect(bucket == ImageBucket.products.rawValue)
        let tables = try await environment.outbox().dropFirst(before).map(\.tableName)
        #expect(tables == ["product_photos", "products"])
        let productFields = TestDatabase.fields(of: try #require(try await environment.outbox().last))
        #expect(productFields["image_path"] as? String == path)
    }

    @Test("A second photo keeps the cover; positions follow the order; recipe photos queue in their own bucket")
    func gallery() async throws {
        let environment = try await FeatureEnvironment.make()
        let product = try await environment.product("Huevos")
        let recipe = try await environment.recipe("Tortilla")
        let image = try TestImages.png(width: 400, height: 300)
        try await environment.addProductPhoto.execute(productID: product.id, imageData: image, asCover: true)
        try await environment.addProductPhoto.execute(productID: product.id, imageData: image, asCover: false)
        try await environment.addPhoto.execute(recipeID: recipe.id, imageData: image, asCover: true)

        let detail = try #require(await firstValue(environment.observeProductDetail.execute(productID: product.id)))
        #expect(detail?.photos.map(\.position) == [0, 1])
        #expect(detail?.gallery.map(\.isCover) == [true, false])
        let buckets = try await environment.database.read { db in
            try String.fetchAll(db, sql: "SELECT bucket FROM pending_image_uploads ORDER BY bucket")
        }
        #expect(buckets == ["product-images", "product-images", "recipe-images"])
    }

    @Test("Deleting the cover photo promotes the next one and drops its pending upload and file")
    func deleteCover() async throws {
        let environment = try await FeatureEnvironment.make()
        let product = try await environment.product("Leche")
        let image = try TestImages.png(width: 400, height: 300)
        try await environment.addProductPhoto.execute(productID: product.id, imageData: image, asCover: true)
        try await environment.addProductPhoto.execute(productID: product.id, imageData: image, asCover: false)
        let detail = try await loadDetail(of: product, in: environment)

        try await environment.deleteProductPhoto.execute(productID: product.id, item: detail.gallery[0])

        let after = try await loadDetail(of: product, in: environment)
        #expect(after.photos.count == 1)
        #expect(after.product.imagePath == detail.photos[1].storagePath)
        #expect(environment.imageFiles.paths(in: .products) == [detail.photos[1].storagePath])
        #expect(try await TestDatabase.count("pending_image_uploads", in: environment.database) == 1)
    }

    @Test("Setting and removing an agent cover outside the gallery")
    func cover() async throws {
        let environment = try await FeatureEnvironment.make()
        let product = try await environment.product("Yogur")
        try await environment.database.writer.write { db in
            try db.execute(
                sql: "UPDATE products SET image_path = 'h/p/ai.png', image_source = 'ai' WHERE id = ?",
                arguments: [product.id.lowercasedString]
            )
        }
        let detail = try await loadDetail(of: product, in: environment)
        #expect(detail.product.imageSource == .agent)
        #expect(detail.gallery == [RecipeGalleryItem(path: "h/p/ai.png", photoID: nil, isCover: true)])

        try await environment.deleteProductPhoto.execute(productID: product.id, item: detail.gallery[0])
        let after = try await loadDetail(of: product, in: environment)
        #expect(after.product.imagePath == nil)
        #expect(after.product.imageSource == nil)
    }

    @Test("Deleting the product tombstones its photos locally")
    func cascade() async throws {
        let environment = try await FeatureEnvironment.make()
        let product = try await environment.product("Arroz")
        try await environment.addProductPhoto.execute(
            productID: product.id,
            imageData: try TestImages.png(width: 100, height: 100),
            asCover: false
        )
        try await environment.products.deleteProduct(id: product.id)
        #expect(
            try await TestDatabase.count("product_photos", in: environment.database, where: "deleted_at IS NULL") == 0
        )
        let detail = await firstValue(environment.observeProductDetail.execute(productID: product.id))
        #expect(detail == .some(nil))
    }

    @Test("Saving the product in the editor keeps its cover")
    func editorKeepsCover() async throws {
        let environment = try await FeatureEnvironment.make()
        let product = try await environment.product("Pan")
        try await environment.addProductPhoto.execute(
            productID: product.id,
            imageData: try TestImages.png(width: 100, height: 100),
            asCover: true
        )
        let saved = try await environment.products.saveProduct(ProductInput(id: product.id, name: "Pan de molde"))
        #expect(saved.imagePath != nil)
        #expect(saved.imageSource == .photo)
    }

    @Test("The detail lists the stores and each recipe that uses the product once")
    func detail() async throws {
        let environment = try await FeatureEnvironment.make()
        let store = try await environment.products.saveStore(StoreInput(name: "Mercadona"))
        let product = try await environment.products.saveProduct(
            ProductInput(name: "Ajos", pricePerKg: 4.5, notes: "Morados", storeIDs: [store.id])
        )
        try await environment.recipe("Pollo al ajillo", products: [product, product])
        try await environment.recipe("Gambas al ajillo", products: [product])
        try await environment.recipe("Ensalada")

        let detail = try await loadDetail(of: product, in: environment)
        #expect(detail.stores.map(\.name) == ["Mercadona"])
        #expect(detail.usages.map(\.recipeName) == ["Gambas al ajillo", "Pollo al ajillo"])
        #expect(detail.usages.first?.quantity == 100)
        #expect(detail.usages.first?.unit == "g")
        #expect(detail.product.notes == "Morados")
    }

    @Test("The upload service sends product photos to product-images")
    func uploadsToProductBucket() async throws {
        let environment = try await FeatureEnvironment.make()
        let product = try await environment.product("Queso")
        let remote = FakeRecipeImageRemote()
        let repository = RecipeImageRepositoryImpl(
            database: environment.database,
            fileDataSource: environment.imageFiles,
            remoteDataSource: remote
        )
        let service = RecipeImageUploadServiceImpl(
            repository: repository,
            reachability: OnlineReachability(),
            loggerService: LoggerServiceImpl(),
            sleep: { _ in }
        )
        try await environment.addProductPhoto.execute(
            productID: product.id,
            imageData: try TestImages.png(width: 200, height: 200),
            asCover: true
        )

        await service.start()
        var pending = 1
        for _ in 0..<100 where pending > 0 {
            try await Task.sleep(for: .milliseconds(30))
            pending = try await TestDatabase.count("pending_image_uploads", in: environment.database)
        }
        #expect(pending == 0)
        #expect(remote.uploadedBuckets == [.products])
        let path = try #require(remote.uploads.first)
        await service.stopAndClear()
        #expect(await repository.imageData(path: path, bucket: .products) != nil)
        #expect(await repository.imageData(path: path, bucket: .recipes) == nil)
    }

    private func loadDetail(of product: Product, in environment: FeatureEnvironment) async throws -> ProductDetail {
        let value = await firstValue(environment.observeProductDetail.execute(productID: product.id))
        return try #require(value ?? nil)
    }
}
