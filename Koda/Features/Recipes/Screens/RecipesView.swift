import SwiftUI

/// Recetas (approved mockup `Recipes`).
struct RecipesView: View {
    @State private var viewModel: RecipesViewModel
    @Environment(AppRouter.self) private var router
    private let container: DependencyContainer

    init(viewModel: RecipesViewModel, container: DependencyContainer = .shared) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KodaSpacing.m) {
                ScreenHeader(
                    subtitle: String(localized: "recipes.count \(viewModel.catalog.count)"),
                    title: String(localized: "tab.recipes")
                ) {
                    NavigationLink(value: AppRoute.products) {
                        Text("recipes.products")
                            .font(KodaTypography.subheadline.weight(.bold))
                            .foregroundStyle(KodaColor.textPrimary)
                            .padding(.horizontal, KodaSpacing.s + 2)
                            .frame(minHeight: KodaSize.hitTarget - 4)
                            .background(KodaColor.surface, in: Capsule())
                            .overlay { Capsule().strokeBorder(KodaColor.brand.opacity(0.18)) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recipes-products")
                }

                RecipeSearchField(text: $viewModel.searchText)

                RecipeFilterChips(viewModel: viewModel)

                if !viewModel.forgotten.isEmpty {
                    VStack(alignment: .leading, spacing: KodaSpacing.s - 2) {
                        SectionHeader(titleKey: "recipes.forgotten.title")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: KodaSpacing.s) {
                                ForEach(Array(viewModel.forgotten.enumerated()), id: \.element.id) { index, item in
                                    NavigationLink(value: AppRoute.recipe(id: item.id)) {
                                        ForgottenRecipeCard(
                                            name: item.recipe.name,
                                            days: item.stats.daysSinceLastEaten(today: viewModel.today) ?? 0,
                                            isFirst: index == 0
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: KodaSpacing.s - 2) {
                    SectionHeader(
                        titleKey: viewModel.filters.isEmpty && viewModel.searchText.isEmpty
                            ? "recipes.all" : "recipes.results"
                    )
                    if viewModel.state == .ready, viewModel.filtered.isEmpty {
                        EmptyStateView(
                            titleKey: viewModel.catalog.isEmpty ? "recipes.empty.title" : "recipes.no-results.title",
                            messageKey: viewModel.catalog.isEmpty
                                ? "recipes.empty.message" : "recipes.no-results.message",
                            actionKey: "recipes.new"
                        ) {
                            Task { await viewModel.send(.newRecipe) }
                        }
                    }
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: KodaSpacing.s)],
                        alignment: .leading,
                        spacing: KodaSpacing.m
                    ) {
                        ForEach(viewModel.filtered) { item in
                            NavigationLink(value: AppRoute.recipe(id: item.id)) {
                                RecipeTile(recipeID: item.id, name: item.recipe.name, detail: detail(item))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("recipe-tile-\(item.id)")
                        }
                    }
                }
            }
            .padding(.horizontal, KodaSpacing.l - 4)
            .padding(.top, KodaSpacing.s)
            .padding(.bottom, KodaSpacing.xl * 3)
        }
        .background(KodaColor.background)
        .navigationTitle(Text("tab.recipes"))
        .platformHidesNavigationBar()
        .dismissKeyboard()
        .keyboardMargin()
        .sheet(item: $viewModel.presentedSheet) { _ in
            RecipeEditorSheet(viewModel: Assembly.makeRecipeEditorViewModel(recipeID: nil, container: container))
        }
        .task { await viewModel.send(.appeared) }
        .onChange(of: router.pendingAction, initial: true) {
            if router.consume(.newRecipe) {
                Task { await viewModel.send(.newRecipe) }
            }
        }
    }

    private func detail(_ item: RecipeCatalogItem) -> String {
        let minutes = item.recipe.timeMinutes.map { String(localized: "recipe.minutes \($0)") }
        let times = item.stats.timesEaten > 0 ? String(localized: "recipes.times \(item.stats.timesEaten)") : nil
        let slot = minutes == nil ? item.recipe.mealTypes.first.map { String(localized: $0.titleResource) } : nil
        return KodaFormat.joined([minutes ?? slot, times])
    }
}

private struct RecipeSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: KodaSpacing.s - 2) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(KodaColor.textTertiary)
                .accessibilityHidden(true)
            TextField("recipes.search", text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .accessibilityIdentifier("recipes-search")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(KodaColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.clear"))
            }
        }
        .padding(.horizontal, KodaSpacing.m)
        .frame(minHeight: 50)
        .background(KodaColor.surface, in: Capsule())
        .shadow(color: KodaColor.walnutDeep.opacity(0.08), radius: 9, y: 6)
    }
}

private struct RecipeFilterChips: View {
    let viewModel: RecipesViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KodaSpacing.xs) {
                ChipView(titleKey: "recipes.filter.all", isSelected: viewModel.filters.isEmpty) {
                    Task { await viewModel.send(.clearFilters) }
                }
                ForEach(RecipeFilter.all, id: \.self) { filter in
                    ChipView(titleKey: filter.titleKey, isSelected: viewModel.filters.contains(filter)) {
                        Task { await viewModel.send(.toggleFilter(filter)) }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

extension RecipeFilter {
    var titleKey: LocalizedStringKey {
        switch self {
        case .mealType(let slot):
            switch slot {
            case .breakfast: "recipes.filter.breakfast"
            case .lunch: "recipes.filter.lunch"
            case .snack: "recipes.filter.snack"
            case .dinner: "recipes.filter.dinner"
            }
        case .quick: "recipes.filter.quick"
        case .nutrient(let nutrient): nutrient.titleKey
        case .favorites: "recipes.filter.favorites"
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Recipes · iPhone") {
        RecipesPreviewFactory.makeRecipesView()
            .kodaPreview()
    }

    #Preview("Recipes · empty") {
        RecipesPreviewFactory.makeRecipesView(container: PreviewContainer.empty)
            .kodaPreview()
    }

    #Preview("Recipes · dark") {
        RecipesPreviewFactory.makeRecipesView()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Recipes · Mac", traits: .fixedLayout(width: 1100, height: 800)) {
        RecipesPreviewFactory.makeRecipesView()
            .kodaPreview()
    }
#endif
