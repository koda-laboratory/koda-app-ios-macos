import Foundation
import GRDB
import Testing

@testable import Koda

@Suite("Recipe photos")
struct RecipePhotoTests {
    @Test("Adding a photo as cover writes the file, the photo, the cover and the upload queue in one step")
    func addAsCover() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Tortilla de patata")
        let before = try await environment.outbox().count

        try await environment.addPhoto.execute(
            recipeID: recipe.id,
            imageData: try TestImages.png(width: 3200, height: 2400),
            asCover: true
        )

        let path = try #require(environment.imageFiles.paths.first)
        #expect(path.hasPrefix("\(TestDatabase.householdID)/\(recipe.id.lowercasedString)/"))
        #expect(path.hasSuffix(".jpg"))
        let stored = try #require(
            try await TestDatabase.string(
                "SELECT image_path || '|' || image_source FROM recipes WHERE id = '\(recipe.id.lowercasedString)'",
                in: environment.database
            )
        )
        #expect(stored == "\(path)|photo")
        let size = try #require(
            try await TestDatabase.string(
                "SELECT width || 'x' || height FROM recipe_photos",
                in: environment.database
            )
        )
        #expect(size == "1600x1200")
        #expect(try await TestDatabase.count("pending_image_uploads", in: environment.database) == 1)
        let tables = try await environment.outbox().dropFirst(before).map(\.tableName)
        #expect(tables == ["recipe_photos", "recipes"])
    }

    @Test("A second photo keeps the cover unless asked; the gallery lists both in order")
    func gallery() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Albóndigas")
        let image = try TestImages.png(width: 400, height: 300)
        try await environment.addPhoto.execute(recipeID: recipe.id, imageData: image, asCover: true)
        try await environment.addPhoto.execute(recipeID: recipe.id, imageData: image, asCover: false)

        let detail = try #require(try await firstDetail(environment, recipe.id))
        #expect(detail.photos.count == 2)
        #expect(detail.gallery.map(\.isCover) == [true, false])
        #expect(detail.recipe.imagePath == detail.photos[0].storagePath)
    }

    @Test("Deleting the cover photo promotes the next one and drops its pending upload and file")
    func deleteCover() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Lentejas")
        let image = try TestImages.png(width: 400, height: 300)
        try await environment.addPhoto.execute(recipeID: recipe.id, imageData: image, asCover: true)
        try await environment.addPhoto.execute(recipeID: recipe.id, imageData: image, asCover: false)
        let detail = try #require(try await firstDetail(environment, recipe.id))

        try await environment.deletePhoto.execute(recipeID: recipe.id, item: detail.gallery[0])

        let after = try #require(try await firstDetail(environment, recipe.id))
        #expect(after.photos.count == 1)
        #expect(after.recipe.imagePath == detail.photos[1].storagePath)
        #expect(environment.imageFiles.paths == [detail.photos[1].storagePath])
        #expect(try await TestDatabase.count("pending_image_uploads", in: environment.database) == 1)
        let deletes = try await environment.outbox().filter { $0.tableName == "recipe_photos" && $0.op == .delete }
        #expect(deletes.count == 1)
    }

    @Test("An agent's cover outside the gallery leads the strip and can be removed")
    func aiCover() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Pizza casera")
        try await environment.database.writer.write { db in
            try db.execute(
                sql: "UPDATE recipes SET image_path = 'h/r/ai.png', image_source = 'ai' WHERE id = ?",
                arguments: [recipe.id.lowercasedString]
            )
        }
        let detail = try #require(try await firstDetail(environment, recipe.id))
        #expect(detail.recipe.imageSource == .agent)
        #expect(detail.gallery == [RecipeGalleryItem(path: "h/r/ai.png", photoID: nil, isCover: true)])

        try await environment.deletePhoto.execute(recipeID: recipe.id, item: detail.gallery[0])
        let after = try #require(try await firstDetail(environment, recipe.id))
        #expect(after.recipe.imagePath == nil)
        #expect(after.recipe.imageSource == nil)
    }

    @Test("A file that is not an image is refused")
    func notAnImage() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Gazpacho")
        await #expect(throws: KodaError.self) {
            try await environment.addPhoto.execute(recipeID: recipe.id, imageData: Data("hola".utf8), asCover: true)
        }
        #expect(try await TestDatabase.count("recipe_photos", in: environment.database) == 0)
    }

    @Test("The upload service drains the queue, retrying after a failure")
    func uploads() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Croquetas")
        let remote = FakeRecipeImageRemote(failures: 1)
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
        try await environment.addPhoto.execute(
            recipeID: recipe.id,
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
        #expect(remote.uploads == environment.imageFiles.paths)
        // Downloads come from disk first, and from Storage (then cached) for images of other devices.
        let path = try #require(remote.uploads.first)
        #expect(await repository.imageData(path: path) != nil)
        await service.stopAndClear()
        #expect(environment.imageFiles.paths.isEmpty)
        #expect(await repository.imageData(path: path) != nil)
        #expect(environment.imageFiles.paths == [path])
    }

    private func firstDetail(_ environment: FeatureEnvironment, _ id: UUID) async throws -> RecipeDetail? {
        var iterator = environment.recipes.observeRecipeDetail(id: id).makeAsyncIterator()
        return await iterator.next() ?? nil
    }
}
