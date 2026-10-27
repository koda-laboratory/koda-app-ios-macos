import Foundation
import GRDB
import Testing

@testable import Koda

@Suite("Recipe links")
struct RecipeLinkTests {
    @Test("Adding links appends them by position, keeps only the URL and enqueues one upsert each")
    func addLinks() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Arroz a la cubana")
        let before = try await environment.outbox().count

        try await environment.addLink.execute(recipeID: recipe.id, text: "Mira https://vm.tiktok.com/ZMabc/ 😋")
        try await environment.addLink.execute(recipeID: recipe.id, text: "https://youtube.com/shorts/xyz")

        let links = try #require(await firstValue(environment.links.observeLinks(recipeID: recipe.id)))
        #expect(links.map(\.url.absoluteString) == ["https://vm.tiktok.com/ZMabc/", "https://youtube.com/shorts/xyz"])
        #expect(links.map(\.position) == [0, 1])
        #expect(links.map(\.info.platform) == [.tiktok, .youtube])
        let entries = try await environment.outbox().dropFirst(before)
        #expect(entries.map(\.tableName) == ["recipe_links", "recipe_links"])
        let fields = TestDatabase.fields(of: try #require(entries.first))
        #expect(fields["url"] as? String == "https://vm.tiktok.com/ZMabc/")
        #expect(fields["recipe_id"] as? String == recipe.id.lowercasedString)
        #expect(fields["household_id"] as? String == TestDatabase.householdID)
    }

    @Test("Text without a link is refused and writes nothing")
    func invalidLink() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Gazpacho")
        await #expect(throws: KodaError.self) {
            try await environment.addLink.execute(recipeID: recipe.id, text: "no es un enlace")
        }
        #expect(try await TestDatabase.count("recipe_links", in: environment.database) == 0)
    }

    @Test("Removing tombstones the link, enqueues a delete and the next one goes after the highest position")
    func removeLink() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Lentejas")
        try await environment.addLink.execute(recipeID: recipe.id, text: "https://tiktok.com/@a/video/1")
        try await environment.addLink.execute(recipeID: recipe.id, text: "https://tiktok.com/@b/video/2")
        let links = try #require(await firstValue(environment.links.observeLinks(recipeID: recipe.id)))

        try await RemoveRecipeLinkUseCaseImpl(repository: environment.links).execute(linkID: links[0].id)
        try await environment.addLink.execute(recipeID: recipe.id, text: "https://tiktok.com/@c/video/3")

        let after = try #require(await firstValue(environment.links.observeLinks(recipeID: recipe.id)))
        #expect(after.map(\.info.account) == ["@b", "@c"])
        #expect(after.map(\.position) == [1, 2])
        let deletes = try await environment.outbox().filter { $0.tableName == "recipe_links" && $0.op == .delete }
        #expect(deletes.map(\.rowId) == [links[0].id.lowercasedString])
    }

    @Test("Deleting the recipe tombstones its links locally")
    func cascade() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Croquetas")
        try await environment.addLink.execute(recipeID: recipe.id, text: "https://youtu.be/abc")

        try await environment.recipes.deleteRecipe(id: recipe.id)

        #expect(
            try await TestDatabase.count("recipe_links", in: environment.database, where: "deleted_at IS NULL") == 0
        )
        #expect(try await TestDatabase.count("recipe_links", in: environment.database) == 1)
    }

    @Test("A link cannot be added to a missing recipe")
    func missingRecipe() async throws {
        let environment = try await FeatureEnvironment.make()
        await #expect(throws: KodaError.self) {
            try await environment.addLink.execute(recipeID: UUID(), text: "https://youtu.be/abc")
        }
    }
}
