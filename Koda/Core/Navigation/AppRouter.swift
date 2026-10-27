import Foundation
import Observation
import SwiftUI

// MARK: - Tab

/// Top-level sections: a tab bar on iPhone and a sidebar on the Mac (`.sidebarAdaptable`).
enum AppTab: String, CaseIterable, Hashable, Sendable {
    case today
    case planning
    case shopping
    case recipes

    var titleKey: LocalizedStringKey {
        switch self {
        case .today: "tab.today"
        case .planning: "tab.planning"
        case .shopping: "tab.shopping"
        case .recipes: "tab.recipes"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .planning: "calendar"
        case .shopping: "cart"
        case .recipes: "book.closed"
        }
    }
}

// MARK: - Route

/// Push destinations available from the tab navigation stacks.
enum AppRoute: Hashable, Sendable {
    case product(id: UUID)
    case products
    case recipe(id: UUID)
    case mealPlanDraft(id: UUID)
}

// MARK: - Quick Action

/// App-wide shortcuts (the "+" button, Mac menu commands, notifications). Selecting one switches to its section;
/// the section's screen consumes it and opens its own feature-owned sheet or focus.
enum AppQuickAction: Hashable, Sendable {
    case addToShopping
    case planMeal
    case newRecipe

    var tab: AppTab {
        switch self {
        case .addToShopping: .shopping
        case .planMeal: .planning
        case .newRecipe: .recipes
        }
    }
}

// MARK: - Router

/// Central navigation state. Each tab keeps an independent typed path.
@MainActor
@Observable
final class AppRouter {
    private var paths: [AppTab: [AppRoute]] = [:]
    var selectedTab = AppTab.today
    /// A quick action waiting for its section's screen to handle it.
    private(set) var pendingAction: AppQuickAction?

    init(selectedTab: AppTab = .today) {
        self.selectedTab = selectedTab
    }

    func request(_ action: AppQuickAction) {
        selectedTab = action.tab
        pendingAction = action
    }

    /// Returns `true` (and clears it) when `action` is pending.
    func consume(_ action: AppQuickAction) -> Bool {
        guard pendingAction == action else { return false }
        pendingAction = nil
        return true
    }

    /// Opens a route in its natural section (notifications, deep links).
    func open(_ route: AppRoute) {
        let tab: AppTab =
            switch route {
            case .recipe, .products, .product: .recipes
            case .mealPlanDraft: .planning
            }
        selectedTab = tab
        paths[tab] = [route]
    }

    func path(for tab: AppTab) -> [AppRoute] {
        paths[tab] ?? []
    }

    func setPath(_ path: [AppRoute], for tab: AppTab) {
        paths[tab] = path
    }

    func navigate(to route: AppRoute, in tab: AppTab? = nil) {
        let targetTab = tab ?? selectedTab
        var path = paths[targetTab] ?? []
        path.append(route)
        paths[targetTab] = path
    }

    func popToRoot(in tab: AppTab? = nil) {
        paths[tab ?? selectedTab] = []
    }
}

// MARK: - Tab Navigation

/// Root navigation stack for one tab. Route registration remains centralized here.
struct AppTabNavigationStack<Content: View>: View {
    let tab: AppTab
    @ViewBuilder let content: () -> Content

    @Environment(AppRouter.self) private var router

    init(tab: AppTab, @ViewBuilder content: @escaping () -> Content) {
        self.tab = tab
        self.content = content
    }

    var body: some View {
        NavigationStack(path: pathBinding) {
            content()
                .navigationDestination(for: AppRoute.self) { route in
                    AppRouteDestination(route: route)
                }
        }
    }

    private var pathBinding: Binding<[AppRoute]> {
        Binding(
            get: { router.path(for: tab) },
            set: { router.setPath($0, for: tab) }
        )
    }
}

// MARK: - Destination

/// The single resolver from `AppRoute` to a screen. Screens are built by their assembly factories.
struct AppRouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .recipe(let id):
            RecipeDetailView(viewModel: Assembly.makeRecipeDetailViewModel(recipeID: id))
        case .products:
            ProductsView(viewModel: Assembly.makeProductsViewModel())
        case .product(let id):
            ProductDetailView(viewModel: Assembly.makeProductDetailViewModel(productID: id))
        case .mealPlanDraft(let id):
            DraftReviewView(viewModel: Assembly.makeDraftReviewViewModel(draftID: id))
        }
    }
}
