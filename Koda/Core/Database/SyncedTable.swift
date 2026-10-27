/// The tables synchronized with `/sync/push` and `/sync/pull`, in the backend's dependency order
/// (`public.synced_tables()`). Column semantics that the generic sync code needs live here.
enum SyncedTable: String, CaseIterable, Sendable, Codable {
    case stores
    case products
    case productStores = "product_stores"
    /// The gallery of a product; the image bytes live in Supabase Storage (`product-images`).
    case productPhotos = "product_photos"
    case recipes
    case recipeIngredients = "recipe_ingredients"
    case recipeComponents = "recipe_components"
    /// The gallery of a recipe; the image bytes live in Supabase Storage (`recipe-images`).
    case recipePhotos = "recipe_photos"
    /// Links to short videos of a recipe (TikTok, Instagram reels, YouTube shorts).
    case recipeLinks = "recipe_links"
    case mealPlanDrafts = "meal_plan_drafts"
    case mealPlanEntries = "meal_plan_entries"
    case consumptions
    case shoppingEntries = "shopping_entries"
    case shoppingEntryItems = "shopping_entry_items"
    /// Server-maintained from shopping status changes; the client only updates `resolved_at`.
    case frozenItems = "frozen_items"

    /// Columns owned by the server: ignored in mutations (`household_id` only counts on insert, so it is sent).
    static let serverOwnedColumns: Set<String> = [
        "id", "created_at", "updated_at", "updated_by", "deleted_at", "client_updated_at", "server_seq",
    ]

    /// `text[]` and `jsonb` columns, stored locally as JSON text and sent as JSON values.
    var jsonColumns: Set<String> {
        switch self {
        case .recipes: ["meal_types", "nutrients", "steps"]
        default: []
        }
    }

    /// `boolean` columns, stored locally as 0/1 and sent as JSON booleans.
    var booleanColumns: Set<String> {
        switch self {
        case .recipes: ["is_favorite"]
        case .shoppingEntries, .shoppingEntryItems: ["checked"]
        default: []
        }
    }

    /// Columns the server sets on its own and the client never sends.
    var serverManagedColumns: Set<String> {
        switch self {
        case .shoppingEntries: ["checked_by"]
        default: []
        }
    }

    /// `true` for the tables resolved with per-field last-writer-wins on the server.
    var usesFieldLevelConflicts: Bool {
        self == .shoppingEntries || self == .shoppingEntryItems
    }

    /// Children tombstoned together with a row of this table, mirroring the backend's
    /// `private.cascade_tombstone` triggers.
    var tombstoneCascades: [(table: SyncedTable, column: String)] {
        switch self {
        case .stores:
            [(.productStores, "store_id")]
        case .products:
            [
                (.productStores, "product_id"), (.recipeIngredients, "product_id"), (.shoppingEntries, "product_id"),
                (.shoppingEntryItems, "product_id"), (.productPhotos, "product_id"),
            ]
        case .recipes:
            [
                (.recipeIngredients, "recipe_id"), (.recipeComponents, "parent_recipe_id"),
                (.recipeComponents, "child_recipe_id"), (.mealPlanEntries, "recipe_id"), (.consumptions, "recipe_id"),
                (.recipePhotos, "recipe_id"), (.recipeLinks, "recipe_id"),
            ]
        case .mealPlanDrafts:
            [(.mealPlanEntries, "draft_id")]
        case .shoppingEntries:
            [(.shoppingEntryItems, "entry_id")]
        case .productStores, .productPhotos, .recipeIngredients, .recipeComponents, .recipePhotos, .recipeLinks,
            .mealPlanEntries, .consumptions, .shoppingEntryItems, .frozenItems:
            []
        }
    }
}
