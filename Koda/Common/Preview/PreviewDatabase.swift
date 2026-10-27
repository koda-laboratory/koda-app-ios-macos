import Foundation
import GRDB

// Seed rows are compact positional tuples on purpose: they read like the table they fill.
// swiftlint:disable large_tuple

/// An in-memory database seeded with a realistic household (recipes, a planned week relative to today, a
/// shopping list with the three states, a frozen item and a pending draft). Previews only: no network.
enum PreviewDatabase {
    enum Content {
        case populated
        case empty
    }

    static func make(_ content: Content = .populated, now: Date = .now) -> AppDatabase {
        do {
            let database = try AppDatabase.makeInMemory()
            try database.writer.write { db in
                try seedHousehold(db)
                if content == .populated {
                    try seedCatalog(db)
                    try seedPlanning(db, today: LocalDay.today(now: now), now: now)
                    try seedShopping(db, today: LocalDay.today(now: now), now: now)
                }
            }
            return database
        } catch {
            fatalError("Preview database could not be seeded: \(error)")
        }
    }

    /// Stable ids: `id(1)` → `00000000-0000-4000-8000-000000000001`.
    static func id(_ index: Int) -> String {
        String(format: "00000000-0000-4000-8000-%012d", index)
    }

    static func uuid(_ index: Int) -> UUID {
        UUID(uuidString: id(index)) ?? UUID()
    }

    // MARK: - Seeds

    private static let household = PreviewHousehold.householdID.lowercasedString
    private static let user = PreviewHousehold.userID.lowercasedString

    private static func seedHousehold(_ db: Database) throws {
        try db.execute(sql: "UPDATE sync_state SET household_id = ? WHERE id = 1", arguments: [household])
        try db.execute(
            sql:
                "INSERT INTO me_profile (user_id, display_name, fetched_at) VALUES (?, 'Manu', '2026-10-22T10:00:00Z')",
            arguments: [user]
        )
        try db.execute(
            sql: """
                INSERT INTO me_households (id, name, timezone, role, position, slot_times, shopping_weekday)
                VALUES (?, 'Casa', 'Europe/Madrid', 'owner', 0,
                        '{"breakfast":"09:00","lunch":"14:30","snack":"18:00","dinner":"21:30"}', 5)
                """,
            arguments: [household]
        )
        try db.execute(
            sql: """
                INSERT INTO me_members (household_id, user_id, role, display_name, avatar_emoji, position)
                VALUES (?, ?, 'owner', 'Manu', NULL, 0), (?, ?, 'member', 'Olga', '🍋', 1)
                """,
            arguments: [household, user, household, PreviewHousehold.partnerID.lowercasedString]
        )
    }

    static let products: [(Int, String, String, String?)] = [
        (101, "Leche", "basics", "l"), (102, "Aceite de oliva", "basics", "l"), (103, "Yogurt griego", "basics", nil),
        (104, "Alitas de pollo", "food", "kg"), (105, "Arroz", "food", "g"), (106, "Huevos", "food", nil),
        (107, "Garbanzos", "food", "g"), (108, "Lechuga", "food", nil), (109, "Suavizante", "cleaning", nil),
        (110, "Carrilleras de cerdo", "food", "g"), (111, "Ajos", "food", "dientes"),
    ]

    static let recipes: [(Int, String, String, Int?, String)] = [
        (201, "Galletas de avena", "[\"breakfast\"]", 20, "[\"fiber\",\"carbs\"]"),
        (202, "Curry de garbanzos", "[\"lunch\"]", 40, "[\"vegetables\",\"protein\"]"),
        (203, "Ensalada César", "[\"dinner\"]", 30, "[\"vegetables\"]"),
        (204, "Arroz a la cubana", "[\"lunch\"]", 45, "[\"carbs\",\"protein\"]"),
        (205, "Paella de carrilleras", "[\"lunch\"]", 90, "[\"protein\"]"),
        (206, "Alitas de pollo", "[\"dinner\"]", 35, "[\"protein\"]"),
        (207, "Gnocchi cabrales con espinacas", "[\"dinner\"]", 25, "[\"carbs\"]"),
        (208, "Tomate frito casero", "[\"lunch\",\"dinner\"]", 60, "[\"vegetables\"]"),
    ]

    private static func seedCatalog(_ db: Database) throws {
        for (index, name) in [(301, "Mercadona"), (302, "Aldi")] {
            try db.execute(
                sql: "INSERT INTO stores (id, household_id, name) VALUES (?, ?, ?)",
                arguments: [id(index), household, name]
            )
        }
        for (index, name, category, unit) in products {
            try db.execute(
                sql: "INSERT INTO products (id, household_id, name, category, default_unit) VALUES (?, ?, ?, ?, ?)",
                arguments: [id(index), household, name, category, unit]
            )
            try db.execute(
                sql: "INSERT INTO product_stores (id, household_id, product_id, store_id) VALUES (?, ?, ?, ?)",
                arguments: [id(index + 1000), household, id(index), id(index % 3 == 0 ? 302 : 301)]
            )
        }
        for (index, name, mealTypes, minutes, nutrients) in recipes {
            try db.execute(
                sql: """
                    INSERT INTO recipes (id, household_id, name, meal_types, nutrients, time_minutes, servings, steps,
                                         notes, is_favorite)
                    VALUES (?, ?, ?, ?, ?, ?, 2, ?, ?, ?)
                    """,
                arguments: [
                    id(index), household, name, mealTypes, nutrients, minutes,
                    "[\"Poner el agua a hervir con sal.\",\"Dorar el ajo y añadir el arroz.\",\"Hacer los huevos.\"]",
                    index == 204 ? "Con caldo de cocido casero queda mucho mejor que con agua." : nil,
                    index == 204 || index == 202,
                ]
            )
        }
        let ingredients: [(Int, Int, Int, Double?, String?)] = [
            (401, 204, 105, 300, "g"), (402, 204, 106, 4, nil), (403, 204, 111, 2, "dientes"),
            (404, 204, 102, nil, nil), (405, 202, 107, 400, "g"), (406, 203, 108, 1, nil),
            (407, 205, 110, 600, "g"), (408, 206, 104, 1, "kg"),
        ]
        for (index, recipe, product, quantity, unit) in ingredients {
            try db.execute(
                sql: """
                    INSERT INTO recipe_ingredients (id, household_id, recipe_id, product_id, quantity, unit, position)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [id(index), household, id(recipe), id(product), quantity, unit, index]
            )
        }
        try db.execute(
            sql: """
                INSERT INTO recipe_components (id, household_id, parent_recipe_id, child_recipe_id, servings_factor)
                VALUES (?, ?, ?, ?, 1)
                """,
            arguments: [id(450), household, id(204), id(208)]
        )
        try seedProductDetail(db)
        try seedRecipeLinks(db)
    }

    /// "Alitas de pollo": emoji, price, notes, both stores, a cover with two more photos and a second recipe.
    private static func seedProductDetail(_ db: Database) throws {
        try db.execute(
            sql: """
                UPDATE products SET emoji = '🍗', price_per_kg = 6.95, image_path = ?, image_source = 'photo',
                                    notes = 'Las de Mercadona vienen en bandeja de 1 kg; congelar en raciones de 500 g.'
                WHERE id = ?
                """,
            arguments: ["\(household)/\(id(104))/cover.jpg", id(104)]
        )
        try db.execute(sql: "UPDATE products SET emoji = '🥚', price_total = 2.4 WHERE id = ?", arguments: [id(106)])
        try db.execute(
            sql: "INSERT INTO product_stores (id, household_id, product_id, store_id) VALUES (?, ?, ?, ?)",
            arguments: [id(2104), household, id(104), id(302)]
        )
        for (position, name) in ["cover", "bandeja", "etiqueta"].enumerated() {
            try db.execute(
                sql: """
                    INSERT INTO product_photos (id, household_id, product_id, storage_path, width, height, position)
                    VALUES (?, ?, ?, ?, 1600, 1200, ?)
                    """,
                arguments: [id(1300 + position), household, id(104), "\(household)/\(id(104))/\(name).jpg", position]
            )
        }
        try db.execute(
            sql: """
                INSERT INTO recipe_ingredients (id, household_id, recipe_id, product_id, quantity, unit, position)
                VALUES (?, ?, ?, ?, 500, 'g', 1)
                """,
            arguments: [id(409), household, id(202), id(104)]
        )
    }

    private static func seedRecipeLinks(_ db: Database) throws {
        let links = [
            "https://www.tiktok.com/@cocinaconana/video/7301234567890",
            "https://www.instagram.com/recetasdelaabuela/reel/C1a2B3c4D5e/",
            "https://youtube.com/shorts/aBcD1234xyz",
        ]
        for (position, url) in links.enumerated() {
            try db.execute(
                sql: "INSERT INTO recipe_links (id, household_id, recipe_id, url, position) VALUES (?, ?, ?, ?, ?)",
                arguments: [id(1400 + position), household, id(204), url, position]
            )
        }
    }

    private static func seedPlanning(_ db: Database, today: LocalDay, now: Date) throws {
        let monday = today.startOfWeek
        var entry = 500
        func plan(_ day: LocalDay, _ slot: MealSlot, recipe: Int?, text: String? = nil, draft: String? = nil) throws {
            entry += 1
            try db.execute(
                sql: """
                    INSERT INTO meal_plan_entries (id, household_id, date, slot, recipe_id, free_text, servings,
                                                   position, draft_id)
                    VALUES (?, ?, ?, ?, ?, ?, 2, 0, ?)
                    """,
                arguments: [id(entry), household, day.description, slot.rawValue, recipe.map(id), text, draft]
            )
        }
        for offset in 0..<7 {
            let day = monday.adding(days: offset)
            try plan(day, .breakfast, recipe: 201)
            try plan(day, .lunch, recipe: [202, 204, 205, 202, 204, 205, 202][offset])
            if offset == 4 {
                try plan(day, .dinner, recipe: nil, text: "Comemos fuera")
            } else if offset != 6 {
                try plan(day, .dinner, recipe: [203, 206, 203, 203, 0, 206, 0][offset])
            }
        }
        // Old consumptions for the stats and "Hace tiempo que no".
        let eaten: [(Int, Int, Int)] = [(601, 207, -21), (602, 204, -9), (603, 204, -16), (604, 206, -34)]
        for (index, recipe, days) in eaten {
            try db.execute(
                sql: """
                    INSERT INTO consumptions (id, household_id, recipe_id, eaten_on, slot, source)
                    VALUES (?, ?, ?, ?, 'dinner', 'auto')
                    """,
                arguments: [id(index), household, id(recipe), today.adding(days: days).description]
            )
        }
        // A pending draft for next week.
        let draft = id(700)
        let nextMonday = monday.adding(days: 7)
        try db.execute(
            sql: """
                INSERT INTO meal_plan_drafts (id, household_id, from_date, to_date, status, source, rationale)
                VALUES (?, ?, ?, ?, 'pending', 'mcp', 'Cenas ligeras y nada repetido de las últimas dos semanas.')
                """,
            arguments: [draft, household, nextMonday.description, nextMonday.adding(days: 6).description]
        )
        try plan(nextMonday, .lunch, recipe: 207, draft: draft)
        try plan(nextMonday, .dinner, recipe: 203, draft: draft)
        _ = now
    }

    private static func seedShopping(_ db: Database, today: LocalDay, now: Date) throws {
        let entries: [(Int, Int?, String?, Double?, String?, String)] = [
            (801, 101, nil, 2, "l", "pending"), (802, 102, nil, 1, "l", "pending"), (803, 103, nil, 4, nil, "pending"),
            (804, 104, nil, 1, "kg", "frozen"), (805, 109, nil, nil, nil, "pending"),
            (806, nil, "Pilas AAA", nil, nil, "pending"),
            (807, 106, nil, 6, nil, "have"),
        ]
        for (position, (index, product, text, quantity, unit, status)) in entries.enumerated() {
            try db.execute(
                sql: """
                    INSERT INTO shopping_entries (id, household_id, kind, product_id, text, quantity, unit, checked,
                                                  status, position)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    id(index), household, product == nil ? "text" : "product", product.map(id), text, quantity, unit,
                    status != "pending", status, position,
                ]
            )
        }
        try db.execute(
            sql: """
                INSERT INTO shopping_entries (id, household_id, kind, recipe_id, text, quantity, unit, status,
                                              source, meal_plan_entry_id, position)
                VALUES (?, ?, 'recipe', ?, 'Arroz a la cubana + Tomate frito casero', 2, 'servings', 'pending',
                        'plan', ?, 10)
                """,
            arguments: [id(850), household, id(204), id(505)]
        )
        let items: [(Int, Int, Double?, String?, String)] = [
            (851, 105, 300, "g", "pending"), (852, 106, 4, nil, "pending"), (853, 111, 2, "dientes", "have"),
        ]
        for (index, product, quantity, unit, status) in items {
            try db.execute(
                sql: """
                    INSERT INTO shopping_entry_items (id, household_id, entry_id, product_id, quantity, unit, checked,
                                                      status)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [id(index), household, id(850), id(product), quantity, unit, status != "pending", status]
            )
        }
        // Frozen chicken wings for this week's dinner, reminder already due.
        try db.execute(
            sql: """
                INSERT INTO frozen_items (id, household_id, product_id, shopping_entry_id, meal_plan_entry_id,
                                          frozen_at, defrost_remind_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                id(900), household, id(104), id(804), id(506),
                ISO8601Timestamp.string(from: now.addingTimeInterval(-86_400)),
                ISO8601Timestamp.string(from: now.addingTimeInterval(-3_600)),
            ]
        )
        _ = today
    }
}

// swiftlint:enable large_tuple
