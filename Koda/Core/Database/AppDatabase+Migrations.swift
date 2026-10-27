import GRDB

// MARK: - Migrations

extension AppDatabase {
    /// Additive, ordered migrations. Never edit a migration that has shipped: add a new one.
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_synced_tables", migrate: SchemaV1.syncedTables)
        migrator.registerMigration("v1_sync_bookkeeping", migrate: SchemaV1.syncBookkeeping)
        migrator.registerMigration("v2_meals_shopping_status_frozen", migrate: SchemaV2.migrate)
        migrator.registerMigration("v3_recipe_images", migrate: SchemaV3.migrate)
        migrator.registerMigration("v4_product_images_recipe_links", migrate: SchemaV4.migrate)
        return migrator
    }
}

/// First schema. Local tables mirror every column of the server tables (`koda-backend` migration
/// `20261022000002_core_schema.sql`) as returned by `/sync/pull`: uuids and timestamps as TEXT (ISO 8601),
/// `date` as `yyyy-MM-dd`, `numeric` as REAL, `boolean` as 0/1, `text[]`/`jsonb` as JSON text.
///
/// There are no foreign keys: pulled rows arrive in any order and are applied independently.
private enum SchemaV1 {
    static func syncedTables(_ db: Database) throws {
        try db.create(table: "stores") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("name", .text).notNull()
            table.column("color", .text)
            syncColumns(table)
        }

        try db.create(table: "products") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("name", .text).notNull()
            table.column("category", .text).notNull().defaults(to: "food")
            table.column("default_unit", .text)
            table.column("price_per_kg", .double)
            table.column("price_total", .double)
            table.column("servings", .double)
            table.column("servings_per_week", .double)
            table.column("notes", .text)
            table.column("emoji", .text)
            syncColumns(table)
        }

        try db.create(table: "product_stores") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("product_id", .text).notNull().indexed()
            table.column("store_id", .text).notNull().indexed()
            syncColumns(table)
        }

        try db.create(table: "recipes") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("name", .text).notNull()
            table.column("meal_types", .text).notNull().defaults(to: "[]")
            table.column("nutrients", .text).notNull().defaults(to: "[]")
            table.column("time_minutes", .integer)
            table.column("servings", .double).notNull().defaults(to: 2)
            table.column("steps", .text).notNull().defaults(to: "[]")
            table.column("notes", .text)
            table.column("image_path", .text)
            table.column("emoji", .text)
            table.column("is_favorite", .boolean).notNull().defaults(to: false)
            syncColumns(table)
        }

        try db.create(table: "recipe_ingredients") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("recipe_id", .text).notNull().indexed()
            table.column("product_id", .text).notNull().indexed()
            table.column("quantity", .double)
            table.column("unit", .text)
            table.column("position", .integer).notNull().defaults(to: 0)
            syncColumns(table)
        }

        try db.create(table: "recipe_components") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("parent_recipe_id", .text).notNull().indexed()
            table.column("child_recipe_id", .text).notNull().indexed()
            table.column("servings_factor", .double).notNull().defaults(to: 1)
            table.column("position", .integer).notNull().defaults(to: 0)
            syncColumns(table)
        }

        try db.create(table: "meal_plan_drafts") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("from_date", .text).notNull()
            table.column("to_date", .text).notNull()
            table.column("status", .text).notNull().defaults(to: "pending")
            table.column("source", .text).notNull().defaults(to: "app")
            table.column("rationale", .text)
            table.column("created_by", .text)
            syncColumns(table)
        }

        try db.create(table: "meal_plan_entries") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("date", .text).notNull().indexed()
            table.column("slot", .text).notNull()
            table.column("recipe_id", .text).indexed()
            table.column("free_text", .text)
            table.column("servings", .double)
            table.column("note", .text)
            table.column("position", .integer).notNull().defaults(to: 0)
            table.column("draft_id", .text).indexed()
            syncColumns(table)
        }

        try db.create(table: "consumptions") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("recipe_id", .text).notNull().indexed()
            table.column("eaten_on", .text).notNull()
            table.column("slot", .text)
            table.column("servings", .double)
            table.column("meal_plan_entry_id", .text).indexed()
            table.column("logged_by", .text)
            syncColumns(table)
        }

        try db.create(table: "shopping_entries") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("kind", .text).notNull()
            table.column("product_id", .text).indexed()
            table.column("recipe_id", .text)
            table.column("text", .text)
            table.column("quantity", .double)
            table.column("unit", .text)
            table.column("checked", .boolean).notNull().defaults(to: false)
            table.column("checked_at", .text)
            table.column("checked_by", .text)
            table.column("name_updated_at", .text)
            table.column("source", .text).notNull().defaults(to: "manual")
            table.column("meal_plan_entry_id", .text)
            table.column("position", .integer).notNull().defaults(to: 0)
            syncColumns(table)
        }

        try db.create(table: "shopping_entry_items") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("entry_id", .text).notNull().indexed()
            table.column("product_id", .text).notNull()
            table.column("quantity", .double)
            table.column("unit", .text)
            table.column("checked", .boolean).notNull().defaults(to: false)
            table.column("checked_at", .text)
            syncColumns(table)
        }
    }

    static func syncBookkeeping(_ db: Database) throws {
        try db.create(table: "outbox") { table in
            table.autoIncrementedPrimaryKey("id")
            table.column("table_name", .text).notNull()
            table.column("row_id", .text).notNull()
            table.column("op", .text).notNull()
            table.column("fields_json", .text)
            table.column("client_ts", .text).notNull()
            table.column("attempts", .integer).notNull().defaults(to: 0)
            table.column("last_error", .text)
            table.column("created_at", .text).notNull()
        }
        try db.create(index: "outbox_row_idx", on: "outbox", columns: ["table_name", "row_id"])

        try db.create(table: "sync_state") { table in
            table.primaryKey("id", .integer).check { $0 == 1 }
            table.column("cursor", .integer).notNull().defaults(to: 0)
            table.column("last_sync_at", .text)
            table.column("household_id", .text)
        }
        try db.execute(sql: "INSERT INTO sync_state (id, cursor) VALUES (1, 0)")

        // Cached `GET /me`.
        try db.create(table: "me_profile") { table in
            table.primaryKey("user_id", .text)
            table.column("display_name", .text)
            table.column("avatar_emoji", .text)
            table.column("fetched_at", .text).notNull()
        }
        try db.create(table: "me_households") { table in
            table.primaryKey("id", .text)
            table.column("name", .text).notNull()
            table.column("timezone", .text).notNull()
            table.column("role", .text).notNull()
            table.column("position", .integer).notNull()
        }
        try db.create(table: "me_members") { table in
            table.column("household_id", .text).notNull()
            table.column("user_id", .text).notNull()
            table.column("role", .text).notNull()
            table.column("display_name", .text)
            table.column("avatar_emoji", .text)
            table.column("position", .integer).notNull()
            table.primaryKey(["household_id", "user_id"])
        }
    }

    /// Sync columns shared by every synced table. `server_seq` is NULL until the row comes back from a pull.
    private static func syncColumns(_ table: TableDefinition) {
        table.column("created_at", .text)
        table.column("updated_at", .text)
        table.column("updated_by", .text)
        table.column("deleted_at", .text)
        table.column("client_updated_at", .text)
        table.column("server_seq", .integer)
    }
}

/// Third product revision (PLAN.md 3.6, backend migrations `…07`–`…10`): household settings in the cached `/me`,
/// meal times and skipped meals, consumption sources, the three-state shopping list and `frozen_items`.
private enum SchemaV2 {
    static func migrate(_ db: Database) throws {
        // Cached `/me`: `slot_times` as JSON text, `shopping_weekday` 1…7 (ISO, Monday = 1).
        try db.alter(table: "me_households") { table in
            table.add(column: "slot_times", .text)
            table.add(column: "shopping_weekday", .integer)
        }

        try db.alter(table: "meal_plan_entries") { table in
            table.add(column: "scheduled_time", .text)
            table.add(column: "skipped_at", .text)
        }

        try db.alter(table: "consumptions") { table in
            table.add(column: "source", .text).notNull().defaults(to: "manual")
        }

        for tableName in ["shopping_entries", "shopping_entry_items"] {
            try db.alter(table: tableName) { table in
                table.add(column: "status", .text).notNull().defaults(to: "pending")
            }
            try db.execute(sql: "UPDATE \(tableName) SET status = 'have' WHERE checked = 1")
        }

        try db.create(table: "frozen_items") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("product_id", .text).notNull().indexed()
            table.column("shopping_entry_id", .text).indexed()
            table.column("shopping_entry_item_id", .text).indexed()
            table.column("meal_plan_entry_id", .text).indexed()
            table.column("frozen_at", .text)
            table.column("defrost_remind_at", .text)
            table.column("reminded_at", .text)
            table.column("resolved_at", .text)
            table.column("created_at", .text)
            table.column("updated_at", .text)
            table.column("updated_by", .text)
            table.column("deleted_at", .text)
            table.column("client_updated_at", .text)
            table.column("server_seq", .integer)
        }
    }
}

/// Recipe images (PLAN.md phase 6b, backend migration `…12`): the cover's source, the `recipe_photos` gallery and
/// the local-only queue of image files waiting to be uploaded to Storage.
private enum SchemaV3 {
    static func migrate(_ db: Database) throws {
        try db.alter(table: "recipes") { table in
            table.add(column: "image_source", .text)
        }

        try db.create(table: "recipe_photos") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("recipe_id", .text).notNull().indexed()
            table.column("storage_path", .text).notNull()
            table.column("width", .integer)
            table.column("height", .integer)
            table.column("position", .integer).notNull().defaults(to: 0)
            table.column("created_at", .text)
            table.column("updated_at", .text)
            table.column("updated_by", .text)
            table.column("deleted_at", .text)
            table.column("client_updated_at", .text)
            table.column("server_seq", .integer)
        }

        // Not synced: images taken on this device that Storage does not have yet.
        try db.create(table: "pending_image_uploads") { table in
            table.primaryKey("storage_path", .text)
            table.column("created_at", .text).notNull()
            table.column("attempts", .integer).notNull().defaults(to: 0)
            table.column("last_error", .text)
        }
    }
}

/// Product images and recipe video links (backend migration `20261027211551`): the product cover, the
/// `product_photos` gallery, `recipe_links`, and the Storage bucket of each queued upload.
private enum SchemaV4 {
    static func migrate(_ db: Database) throws {
        try db.alter(table: "products") { table in
            table.add(column: "image_path", .text)
            table.add(column: "image_source", .text)
        }

        try db.create(table: "product_photos") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("product_id", .text).notNull().indexed()
            table.column("storage_path", .text).notNull()
            table.column("width", .integer)
            table.column("height", .integer)
            table.column("position", .integer).notNull().defaults(to: 0)
            syncColumns(table)
        }

        try db.create(table: "recipe_links") { table in
            table.primaryKey("id", .text)
            table.column("household_id", .text).notNull()
            table.column("recipe_id", .text).notNull().indexed()
            table.column("url", .text).notNull()
            table.column("position", .integer).notNull().defaults(to: 0)
            syncColumns(table)
        }

        // Every image queued before this version belongs to a recipe.
        try db.alter(table: "pending_image_uploads") { table in
            table.add(column: "bucket", .text).notNull().defaults(to: "recipe-images")
        }

        // Earlier versions already pulled rows of these tables and columns and ignored them (forward
        // compatibility), and the cursor is past them: the next sync pulls everything again from 0. Pulled rows are
        // upserted by id (never older over newer) and pending local changes are rebased on top, so the local rows
        // and the outbox stay as they are.
        try db.execute(sql: "UPDATE sync_state SET cursor = 0 WHERE id = 1")
    }

    private static func syncColumns(_ table: TableDefinition) {
        table.column("created_at", .text)
        table.column("updated_at", .text)
        table.column("updated_by", .text)
        table.column("deleted_at", .text)
        table.column("client_updated_at", .text)
        table.column("server_seq", .integer)
    }
}
