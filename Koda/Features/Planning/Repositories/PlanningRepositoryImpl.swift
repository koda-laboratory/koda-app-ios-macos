import Foundation
import GRDB

final class PlanningRepositoryImpl: PlanningRepository, Sendable {
    // MARK: - Properties

    private let database: AppDatabase
    private let writer: LocalMutationWriter
    private let remoteDataSource: any PlanningRemoteDataSource

    // MARK: - Lifecycle

    init(database: AppDatabase, writer: LocalMutationWriter, remoteDataSource: any PlanningRemoteDataSource) {
        self.database = database
        self.writer = writer
        self.remoteDataSource = remoteDataSource
    }

    // MARK: - Observation

    func observeEntries(from: LocalDay, through: LocalDay) -> AsyncStream<[MealPlanEntry]> {
        let lower = from.description
        let upper = through.description
        return database.observe { db in
            let rows = try Row.fetchAll(
                db,
                sql: Self.entrySelect + " WHERE e.deleted_at IS NULL AND e.draft_id IS NULL AND e.date BETWEEN ? AND ?",
                arguments: [lower, upper]
            )
            return MealPlanEntry.ordered(rows.compactMap(MealPlanEntry.init(row:)))
        }
    }

    func observePendingDrafts() -> AsyncStream<[MealPlanDraft]> {
        database.observe { db in
            let drafts = try MealPlanDraftRecord.live()
                .filter(Column("status") == MealPlanDraftStatus.pending.rawValue)
                .order(Column("from_date"))
                .fetchAll(db)
            guard !drafts.isEmpty else { return [] }
            let rows = try Row.fetchAll(
                db,
                sql: Self.entrySelect + " WHERE e.deleted_at IS NULL AND e.draft_id IS NOT NULL"
            )
            let entriesByDraft = Dictionary(grouping: rows.compactMap(MealPlanEntry.init(row:))) { $0.draftID }
            return drafts.compactMap { record in
                MealPlanDraft(record: record, entries: entriesByDraft[UUID(uuidString: record.id)] ?? [])
            }
        }
    }

    // MARK: - Mutations

    @discardableResult
    func planMeal(_ input: NewMealPlanEntry) async throws(KodaError) -> MealPlanEntry {
        let writer = writer
        return try await database.write { db in
            let day = input.day.description
            let position =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COALESCE(MAX(position), -1) + 1 FROM meal_plan_entries
                        WHERE date = ? AND slot = ? AND deleted_at IS NULL AND draft_id IS NULL
                        """,
                    arguments: [day, input.slot.rawValue]
                ) ?? 0
            let record = try writer.save(
                MealPlanEntryRecord(
                    id: LocalMutationWriter.newID(),
                    householdId: "",
                    date: day,
                    slot: input.slot.rawValue,
                    recipeId: input.recipeID?.lowercasedString,
                    freeText: input.freeText,
                    servings: input.servings,
                    note: input.note,
                    position: position,
                    draftId: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    updatedBy: nil,
                    deletedAt: nil,
                    clientUpdatedAt: nil,
                    serverSeq: nil
                ),
                in: db
            )
            guard
                let row = try Row.fetchOne(db, sql: Self.entrySelect + " WHERE e.id = ?", arguments: [record.id]),
                let entry = MealPlanEntry(row: row)
            else {
                throw KodaError(type: .internal, reason: "Invalid meal plan entry \(record.id).")
            }
            return entry
        }
    }

    func removeEntry(id: UUID) async throws(KodaError) {
        let writer = writer
        try await database.write { db in try writer.delete(.mealPlanEntries, id: id.lowercasedString, in: db) }
    }

    @discardableResult
    func logConsumption(_ input: NewConsumption) async throws(KodaError) -> Consumption {
        let writer = writer
        return try await database.write { db in
            let context = try writer.context(db)
            let record = try writer.save(
                ConsumptionRecord(
                    id: LocalMutationWriter.newID(),
                    householdId: context.householdID,
                    recipeId: input.recipeID.lowercasedString,
                    eatenOn: input.day.description,
                    slot: input.slot?.rawValue,
                    servings: input.servings,
                    mealPlanEntryId: input.mealPlanEntryID?.lowercasedString,
                    loggedBy: context.userID,
                    createdAt: nil,
                    updatedAt: nil,
                    updatedBy: nil,
                    deletedAt: nil,
                    clientUpdatedAt: nil,
                    serverSeq: nil
                ),
                in: db
            )
            guard let consumption = Consumption(record: record) else {
                throw KodaError(type: .internal, reason: "Invalid consumption \(record.id).")
            }
            return consumption
        }
    }

    func removeConsumption(id: UUID) async throws(KodaError) {
        let writer = writer
        try await database.write { db in try writer.delete(.consumptions, id: id.lowercasedString, in: db) }
    }

    func acceptDraft(id: UUID) async throws(KodaError) -> Int {
        try await remoteDataSource.acceptDraft(id: id.lowercasedString).entries
    }

    func discardDraft(id: UUID) async throws(KodaError) -> Int {
        try await remoteDataSource.discardDraft(id: id.lowercasedString).entries
    }

    // MARK: - Queries

    private static let entrySelect = """
        SELECT e.id, e.date, e.slot, e.recipe_id, e.free_text, e.servings, e.note, e.position, e.draft_id,
               r.name AS recipe_name, r.emoji AS recipe_emoji,
               (SELECT c.id FROM consumptions c
                WHERE c.meal_plan_entry_id = e.id AND c.deleted_at IS NULL LIMIT 1) AS consumption_id
        FROM meal_plan_entries e
        LEFT JOIN recipes r ON r.id = e.recipe_id AND r.deleted_at IS NULL
        """
}

// MARK: - Mapping

extension MealPlanEntry {
    init?(row: Row) {
        guard let id = UUID(uuidString: row["id"]),
            let day = LocalDay(row["date"] as String),
            let slot = MealSlot(rawValue: row["slot"])
        else {
            return nil
        }
        self.init(
            id: id,
            day: day,
            slot: slot,
            recipeID: (row["recipe_id"] as String?).flatMap(UUID.init(uuidString:)),
            recipeName: row["recipe_name"],
            recipeEmoji: row["recipe_emoji"],
            freeText: row["free_text"],
            servings: row["servings"],
            note: row["note"],
            position: row["position"],
            draftID: (row["draft_id"] as String?).flatMap(UUID.init(uuidString:)),
            consumptionID: (row["consumption_id"] as String?).flatMap(UUID.init(uuidString:))
        )
    }
}

extension MealPlanDraft {
    init?(record: MealPlanDraftRecord, entries: [MealPlanEntry]) {
        guard let id = UUID(uuidString: record.id),
            let fromDay = LocalDay(record.fromDate),
            let toDay = LocalDay(record.toDate)
        else {
            return nil
        }
        self.init(
            id: id,
            fromDay: fromDay,
            toDay: toDay,
            status: MealPlanDraftStatus(rawValue: record.status) ?? .pending,
            source: MealPlanDraftSource(rawValue: record.source) ?? .app,
            rationale: record.rationale,
            entries: MealPlanEntry.ordered(entries)
        )
    }
}

extension Consumption {
    init?(record: ConsumptionRecord) {
        guard let id = UUID(uuidString: record.id),
            let recipeID = UUID(uuidString: record.recipeId),
            let day = LocalDay(record.eatenOn)
        else {
            return nil
        }
        self.init(
            id: id,
            recipeID: recipeID,
            day: day,
            slot: record.slot.flatMap(MealSlot.init(rawValue:)),
            servings: record.servings,
            mealPlanEntryID: record.mealPlanEntryId.flatMap(UUID.init(uuidString:))
        )
    }
}
