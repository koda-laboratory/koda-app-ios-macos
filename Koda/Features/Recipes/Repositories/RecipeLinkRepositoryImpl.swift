import Foundation
import GRDB

final class RecipeLinkRepositoryImpl: RecipeLinkRepository, Sendable {
    // MARK: - Properties

    private let database: AppDatabase
    private let writer: LocalMutationWriter

    // MARK: - Lifecycle

    init(database: AppDatabase, writer: LocalMutationWriter) {
        self.database = database
        self.writer = writer
    }

    // MARK: - RecipeLinkRepository

    func observeLinks(recipeID: UUID) -> AsyncStream<[RecipeLink]> {
        let recipeKey = recipeID.lowercasedString
        return database.observe { db in
            try RecipeLinkRecord.live()
                .filter(Column("recipe_id") == recipeKey)
                .order(Column("position"), Column("created_at"))
                .fetchAll(db)
                .compactMap(RecipeLink.init(record:))
        }
    }

    @discardableResult
    func addLink(recipeID: UUID, url: URL) async throws(KodaError) -> RecipeLink {
        let writer = writer
        let recipeKey = recipeID.lowercasedString
        let record = try await database.write { db in
            guard let recipe = try RecipeRecord.fetchOne(db, key: recipeKey), !recipe.isDeleted else {
                throw KodaError(type: .notFound, reason: "Recipe \(recipeID) not found.")
            }
            let position =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COALESCE(MAX(position), -1) + 1 FROM recipe_links
                        WHERE recipe_id = ? AND deleted_at IS NULL
                        """,
                    arguments: [recipeKey]
                ) ?? 0
            return try writer.save(
                RecipeLinkRecord(
                    id: LocalMutationWriter.newID(),
                    householdId: recipe.householdId,
                    recipeId: recipeKey,
                    url: url.absoluteString,
                    position: position
                ),
                in: db
            )
        }
        guard let link = RecipeLink(record: record) else {
            throw KodaError(type: .internal, reason: "Invalid recipe link \(record.id).")
        }
        return link
    }

    func removeLink(id: UUID) async throws(KodaError) {
        let writer = writer
        try await database.write { db in try writer.delete(.recipeLinks, id: id.lowercasedString, in: db) }
    }
}

// MARK: - Mapping

extension RecipeLink {
    init?(record: RecipeLinkRecord) {
        guard let id = UUID(uuidString: record.id), let recipeID = UUID(uuidString: record.recipeId),
            let url = URL(string: record.url)
        else { return nil }
        self.init(id: id, recipeID: recipeID, url: url, position: record.position)
    }
}

extension RecipeLinkRecord {
    init(id: String, householdId: String, recipeId: String, url: String, position: Int) {
        self.init(
            id: id,
            householdId: householdId,
            recipeId: recipeId,
            url: url,
            position: position,
            createdAt: nil,
            updatedAt: nil,
            updatedBy: nil,
            deletedAt: nil,
            clientUpdatedAt: nil,
            serverSeq: nil
        )
    }
}
