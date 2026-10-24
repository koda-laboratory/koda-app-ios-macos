import SwiftUI

/// The signed-in app: Hoy · Planning · Compra · Recetas as a Liquid Glass tab bar on iPhone and a sidebar on the
/// Mac, with the discreet offline indicator and the "+" quick actions on every section.
struct MainTabView: View {
    /// A tab bar item: a section, or the iPhone "+" that only opens the quick actions.
    private enum TabItem: Hashable {
        case section(AppTab)
        case quickActions
    }

    @State private var viewModel: ShellViewModel
    @State private var showsQuickActions = false
    @Environment(AppRouter.self) private var router
    private let container: DependencyContainer

    init(viewModel: ShellViewModel, container: DependencyContainer = .shared) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }

    var body: some View {
        TabView(selection: selection) {
            Tab(AppTab.today.titleKey, systemImage: "house", value: TabItem.section(.today)) {
                section(.today) { TodayView(viewModel: Assembly.makeTodayViewModel(container: container)) }
            }
            Tab(AppTab.planning.titleKey, systemImage: AppTab.planning.systemImage, value: TabItem.section(.planning)) {
                section(.planning) { PlanningView(viewModel: Assembly.makePlanningViewModel(container: container)) }
            }
            Tab(AppTab.shopping.titleKey, systemImage: "bag", value: TabItem.section(.shopping)) {
                section(.shopping) { ShoppingView(viewModel: Assembly.makeShoppingViewModel(container: container)) }
            }
            Tab(AppTab.recipes.titleKey, systemImage: AppTab.recipes.systemImage, value: TabItem.section(.recipes)) {
                section(.recipes) { RecipesView(viewModel: Assembly.makeRecipesViewModel(container: container)) }
            }
            if PlatformIdiom.current == .phone {
                // The `.search` role is what places an item apart at the trailing end of the iPhone tab bar;
                // here it hosts the "+" instead of search, and selecting it never leaves the current section.
                Tab("quick-actions.title", systemImage: "plus", value: TabItem.quickActions, role: .search) {
                    Color.clear
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .quickActionsDialog(isPresented: $showsQuickActions) { router.request($0) }
        .platformHaptic(.impact(weight: .light), trigger: showsQuickActions) { _, isShown in isShown }
        .tabViewSidebarHeader {
            SidebarBrandHeader()
        }
        .tabViewSidebarFooter {
            SidebarAccountFooter(household: viewModel.household, status: viewModel.syncStatus)
        }
        .task { await viewModel.send(.appeared) }
    }

    /// Section tabs drive the router; the "+" opens the quick actions and keeps the current section selected.
    private var selection: Binding<TabItem> {
        Binding(
            get: { .section(router.selectedTab) },
            set: { item in
                switch item {
                case .section(let tab): router.selectedTab = tab
                case .quickActions: showsQuickActions = true
                }
            }
        )
    }

    private func section<Content: View>(_ tab: AppTab, @ViewBuilder content: @escaping () -> Content) -> some View {
        AppTabNavigationStack(tab: tab) {
            content()
                .safeAreaInset(edge: .top, spacing: 0) {
                    OfflineBanner(status: viewModel.syncStatus)
                        .padding(.vertical, viewModel.syncStatus.isOnline ? 0 : KodaSpacing.xs)
                        .kodaAnimation(.easeInOut, value: viewModel.syncStatus.isOnline)
                }
                .quickActions { router.request($0) }
        }
    }
}

/// Koda's arcs and name at the top of the Mac sidebar.
private struct SidebarBrandHeader: View {
    var body: some View {
        HStack(spacing: KodaSpacing.xs) {
            KodaArcs()
                .frame(width: 26)
            Text("app.name")
                .font(KodaTypography.title)
                .foregroundStyle(KodaColor.textPrimary)
            Spacer()
        }
        .padding(.horizontal, KodaSpacing.xs)
        .padding(.bottom, KodaSpacing.s)
    }
}

/// The signed-in user and the sync state at the bottom of the Mac sidebar.
private struct SidebarAccountFooter: View {
    let household: HouseholdContext?
    let status: SyncStatus

    var body: some View {
        HStack(spacing: KodaSpacing.s - 2) {
            Text(verbatim: String((household?.displayName ?? "K").prefix(1)).uppercased())
                .font(KodaTypography.subheadline.weight(.heavy))
                .foregroundStyle(KodaColor.cream)
                .frame(width: 30, height: 30)
                .background(KodaColor.brand, in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: household?.displayName ?? "")
                    .font(KodaTypography.subheadline.weight(.bold))
                Text(statusKey)
                    .font(KodaTypography.caption)
                    .foregroundStyle(KodaColor.textSecondary)
            }
            Spacer()
        }
        .padding(KodaSpacing.s - 2)
        .background(KodaColor.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: KodaRadius.small))
        .accessibilityElement(children: .combine)
    }

    private var statusKey: LocalizedStringKey {
        if !status.isOnline { return "sync.offline.short" }
        if status.isSyncing { return "sync.syncing" }
        return status.pendingChanges > 0 ? "sync.pending \(status.pendingChanges)" : "sync.synced"
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Main · iPhone") {
        MainTabView(
            viewModel: Assembly.makeShellViewModel(container: PreviewContainer.populated),
            container: PreviewContainer.populated
        )
        .environment(AppRouter())
        .kodaPreview()
    }

    #Preview("Main · dark") {
        MainTabView(
            viewModel: Assembly.makeShellViewModel(container: PreviewContainer.populated),
            container: PreviewContainer.populated
        )
        .environment(AppRouter())
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Main · Mac", traits: .fixedLayout(width: 1280, height: 800)) {
        MainTabView(
            viewModel: Assembly.makeShellViewModel(container: PreviewContainer.populated),
            container: PreviewContainer.populated
        )
        .environment(AppRouter(selectedTab: .planning))
        .kodaPreview()
    }
#endif
