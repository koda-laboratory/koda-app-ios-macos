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
    case recipe(id: UUID)
}

// MARK: - Router

/// Central navigation state. Each tab keeps an independent typed path.
@MainActor
@Observable
final class AppRouter {
    private var paths: [AppTab: [AppRoute]] = [:]
    var selectedTab = AppTab.today

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

struct AppRouteDestination: View {
    let route: AppRoute

    var body: some View {
        // Feature screens arrive in Phase 3; until then every destination is a placeholder.
        switch route {
        case .product, .recipe:
            ContentUnavailableView("common.coming-soon", systemImage: "hammer")
        }
    }
}
