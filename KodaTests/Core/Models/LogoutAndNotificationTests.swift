import Foundation
import Testing

@testable import Koda

@Suite("Defrost notifications")
struct KodaNotificationTests {
    @Test("A defrost payload opens its recipe; other payloads are ignored")
    func route() {
        let recipeID = UUID()
        let payload: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "Descongela", "body": "Mañana toca paella"], "category": "DEFROST"],
            "koda": ["kind": "defrost", "frozen_item_id": UUID().uuidString, "recipe_id": recipeID.uuidString],
        ]
        #expect(KodaNotification.route(for: payload) == .recipe(id: recipeID))
        #expect(KodaNotification.route(for: ["koda": ["reason": "shopping"]]) == nil)
        #expect(KodaNotification.route(for: ["koda": ["kind": "defrost"]]) == nil)
    }

    @MainActor
    @Test("Opening a route selects its section and replaces that section's path")
    func routerOpen() {
        let router = AppRouter()
        router.navigate(to: .products, in: .recipes)
        let id = UUID()
        router.open(.recipe(id: id))
        #expect(router.selectedTab == .recipes)
        #expect(router.path(for: .recipes) == [.recipe(id: id)])

        router.request(.addToShopping)
        #expect(router.selectedTab == .shopping)
        #expect(router.consume(.newRecipe) == false)
        #expect(router.consume(.addToShopping))
        #expect(router.pendingAction == nil)
    }

    @Test("Household settings decode when present and default when the backend does not send them yet")
    func meDecoding() throws {
        let withSettings = Data(
            """
            {"id":"h","name":"Casa","timezone":"Europe/Madrid","role":"owner","members":[],
             "slot_times":{"breakfast":"08:00","lunch":"14:00","snack":"18:00","dinner":"21:00"},"shopping_weekday":6}
            """.utf8
        )
        let decoded = try JSONDecoder.supabase().decode(MeHouseholdDTO.self, from: withSettings)
        #expect(decoded.shoppingWeekday == 6)
        #expect(SlotTimes(strings: decoded.slotTimes ?? [:]).breakfast == LocalTime(hour: 8, minute: 0))

        let legacy = Data(#"{"id":"h","name":"Casa","timezone":"Europe/Madrid","role":"owner","members":[]}"#.utf8)
        let old = try JSONDecoder.supabase().decode(MeHouseholdDTO.self, from: legacy)
        #expect(old.slotTimes == nil)
        #expect(old.shoppingWeekday == nil)
    }
}
