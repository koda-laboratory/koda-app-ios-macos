import SwiftUI

/// The signed-in app: Hoy · Planning · Compra · Recetas as a Liquid Glass tab bar on iPhone and a sidebar on the
/// Mac, with the discreet offline indicator and the "+" quick actions on every section.
struct MainTabView: View {
    @State private var viewModel: ShellViewModel
    @Environment(AppRouter.self) private var router
    private let container: DependencyContainer

    init(viewModel: ShellViewModel, container: DependencyContainer = .shared) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab(AppTab.today.titleKey, systemImage: "house", value: AppTab.today) {
                section(.today) { TodayView(viewModel: Assembly.makeTodayViewModel(container: container)) }
            }
            Tab(AppTab.planning.titleKey, systemImage: AppTab.planning.systemImage, value: AppTab.planning) {
                section(.planning) { PlanningView(viewModel: Assembly.makePlanningViewModel(container: container)) }
            }
            Tab(AppTab.shopping.titleKey, systemImage: "bag", value: AppTab.shopping) {
                section(.shopping) { ShoppingView(viewModel: Assembly.makeShoppingViewModel(container: container)) }
            }
            Tab(AppTab.recipes.titleKey, systemImage: AppTab.recipes.systemImage, value: AppTab.recipes) {
                section(.recipes) { RecipesView(viewModel: Assembly.makeRecipesViewModel(container: container)) }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSidebarHeader {
            SidebarBrandHeader()
        }
        .tabViewSidebarFooter {
            SidebarAccountFooter(household: viewModel.household, status: viewModel.syncStatus)
        }
        .task { await viewModel.send(.appeared) }
    }

    private func section<Content: View>(_ tab: AppTab, @ViewBuilder content: @escaping () -> Content) -> some View {
        AppTabNavigationStack(tab: tab) {
            content()
                .safeAreaInset(edge: .top, spacing: 0) {
                    OfflineBanner(status: viewModel.syncStatus)
                        .padding(.vertical, viewModel.syncStatus.isOnline ? 0 : KodaSpacing.xs)
                        .animation(.easeInOut, value: viewModel.syncStatus.isOnline)
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
