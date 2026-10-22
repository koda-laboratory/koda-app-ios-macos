import Foundation
import Testing

@testable import Koda

private actor StubNotificationRepository: NotificationRepository {
    var status: NotificationAuthorization
    private(set) var requests = 0

    init(status: NotificationAuthorization) {
        self.status = status
    }

    func authorization() async -> NotificationAuthorization { status }

    func requestAuthorization() async throws(KodaError) -> Bool {
        requests += 1
        status = .authorized
        return true
    }
}

@MainActor
@Suite("Shopping screen")
struct ShoppingViewModelTests {
    private func makeViewModel(
        _ environment: FeatureEnvironment,
        notifications: StubNotificationRepository = StubNotificationRepository(status: .authorized)
    ) -> ShoppingViewModel {
        ShoppingViewModel(
            useCases: ShoppingViewModel.UseCases(
                observeShoppingList: environment.observeShoppingList,
                observeFrozenItems: environment.observeFrozenItems,
                observeProducts: environment.observeProducts,
                observeRecipeCatalog: environment.observeCatalog,
                observeHousehold: environment.observeHousehold,
                addShoppingEntry: AddShoppingEntryUseCaseImpl(repository: environment.shopping),
                addRecipeToShoppingList: environment.addRecipeToShopping,
                setEntryStatus: SetShoppingEntryStatusUseCaseImpl(repository: environment.shopping),
                setItemStatus: SetShoppingItemStatusUseCaseImpl(repository: environment.shopping),
                removeEntry: RemoveShoppingEntryUseCaseImpl(repository: environment.shopping),
                clearHave: ClearCheckedShoppingEntriesUseCaseImpl(repository: environment.shopping),
                getNotificationAuthorization: GetNotificationAuthorizationUseCaseImpl(repository: notifications),
                requestNotificationAuthorization: RequestNotificationAuthorizationUseCaseImpl(repository: notifications)
            ),
            clock: { TestClock.now }
        )
    }

    private func layout(_ viewModel: ShoppingViewModel) -> ShoppingLayout {
        viewModel.layout(
            categoryTitle: { $0.rawValue },
            otherTitle: "other",
            noStoreTitle: "none",
            quantity: { quantity, unit in KodaFormat.quantity(quantity, unit: unit) }
        )
    }

    @Test("Quick add picks the catalog product on an exact name, otherwise free text; suggestions autocomplete")
    func quickAdd() async throws {
        let environment = try await FeatureEnvironment.make()
        try await environment.product("Leche", category: .basics)
        let viewModel = makeViewModel(environment)
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.state == .ready && viewModel.products.count == 1 })

        viewModel.quickAddText = "lec"
        #expect(viewModel.suggestions.first == .product(try #require(viewModel.products.first)))
        #expect(viewModel.suggestions.last == .text("lec"))

        viewModel.quickAddText = "leche"
        await viewModel.send(.submitQuickAdd)
        viewModel.quickAddText = "Pilas AAA"
        await viewModel.send(.submitQuickAdd)
        #expect(viewModel.quickAddText.isEmpty)
        #expect(await eventually { viewModel.entries.count == 2 })
        #expect(viewModel.entries.map(\.kind) == [.product, .text])
        #expect(layout(viewModel).pendingGroups.map(\.title) == ["basics", "other"])
        #expect(viewModel.cycle.shoppingDay.description == "2026-10-23")
    }

    @Test("Rows move between to buy, the freezer and we have it")
    func threeStates() async throws {
        let environment = try await FeatureEnvironment.make()
        try await environment.shopping.addEntry(
            NewShoppingEntry(item: .product(try await environment.product("Alitas").id))
        )
        let viewModel = makeViewModel(environment)
        await viewModel.send(.appeared)
        #expect(await eventually { layout(viewModel).pendingCount == 1 })
        let row = try #require(layout(viewModel).pendingGroups.first?.rows.first)

        await viewModel.send(.toggleFrozen(row))
        #expect(await eventually { layout(viewModel).frozenRows.count == 1 })
        #expect(layout(viewModel).pendingCount == 0)

        await viewModel.send(.toggleHave(try #require(layout(viewModel).frozenRows.first)))
        #expect(await eventually { layout(viewModel).haveRows.count == 1 })

        await viewModel.send(.clearHave)
        #expect(await eventually { layout(viewModel).isEmpty })
    }

    @Test("The first frozen product explains and asks for notification permission")
    func notificationPermission() async throws {
        let environment = try await FeatureEnvironment.make()
        try await environment.shopping.addEntry(
            NewShoppingEntry(item: .product(try await environment.product("Carrilleras").id))
        )
        let notifications = StubNotificationRepository(status: .notDetermined)
        let viewModel = makeViewModel(environment, notifications: notifications)
        await viewModel.send(.appeared)
        #expect(await eventually { layout(viewModel).pendingCount == 1 })

        await viewModel.send(.toggleFrozen(try #require(layout(viewModel).pendingGroups.first?.rows.first)))
        #expect(viewModel.presentedSheet == .notificationsExplanation)
        await viewModel.send(.enableNotifications)
        #expect(viewModel.presentedSheet == nil)
        #expect(await notifications.requests == 1)

        // Once decided, freezing again does not ask.
        #expect(await eventually { layout(viewModel).frozenRows.count == 1 })
        await viewModel.send(.toggleFrozen(try #require(layout(viewModel).frozenRows.first)))
        await viewModel.send(.toggleFrozen(try #require(await firstPending(viewModel))))
        #expect(viewModel.presentedSheet == nil)
    }

    private func firstPending(_ viewModel: ShoppingViewModel) async -> ShoppingRow? {
        _ = await eventually { layout(viewModel).pendingCount == 1 }
        return layout(viewModel).pendingGroups.first?.rows.first
    }

    @Test("Recipe entries expand and their products change state one by one")
    func recipeEntries() async throws {
        let environment = try await FeatureEnvironment.make()
        let rice = try await environment.product("Arroz")
        let recipe = try await environment.recipe("Arroz a la cubana", products: [rice])
        let viewModel = makeViewModel(environment)
        await viewModel.send(.appeared)
        #expect(await eventually { viewModel.state == .ready })

        await viewModel.send(.pickSuggestion(.recipe(recipe)))
        #expect(await eventually { layout(viewModel).recipeEntries.count == 1 })
        let entry = try #require(layout(viewModel).recipeEntries.first)
        await viewModel.send(.toggleExpanded(entry.id))
        #expect(viewModel.expandedEntryIDs.contains(entry.id))

        let item = try #require(entry.items.first)
        let row = ShoppingRow(
            source: .item(entryID: entry.id, itemID: item.id),
            title: item.productName,
            quantityText: "",
            status: item.status,
            category: nil,
            storeNames: [],
            isText: false,
            recipeTitle: entry.title
        )
        await viewModel.send(.toggleFrozen(row))
        #expect(await eventually { layout(viewModel).frozenRows.first?.recipeTitle == "Arroz a la cubana" })
    }
}
