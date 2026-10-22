import SwiftUI

/// Recipe detail (approved mockup `RecipeDetail`).
struct RecipeDetailView: View {
    @State private var viewModel: RecipeDetailViewModel
    @Environment(\.locale) private var locale
    private let container: DependencyContainer

    init(viewModel: RecipeDetailViewModel, container: DependencyContainer = .shared) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .missing:
                ContentUnavailableView("recipe.missing", systemImage: "book.closed")
            case .loaded:
                if let detail = viewModel.detail {
                    content(detail)
                }
            }
        }
        .background(KodaColor.background)
        .platformMacNavigationTitle(viewModel.detail?.recipe.name ?? "")
        .platformInlineNavigationTitle()
        .platformTransparentNavigationBar()
        .toolbar {
            if let recipe = viewModel.detail?.recipe {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.send(.toggleFavorite) }
                    } label: {
                        Label(
                            recipe.isFavorite ? "recipe.favorite.remove" : "recipe.favorite.add",
                            systemImage: recipe.isFavorite ? "heart.fill" : "heart"
                        )
                    }
                    .symbolEffect(.bounce, value: recipe.isFavorite)
                    .accessibilityIdentifier("recipe-favorite")
                    Button {
                        Task { await viewModel.send(.edit) }
                    } label: {
                        Label("recipe.edit", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("recipe-edit")
                }
            }
        }
        .dismissKeyboard()
        .keyboardMargin()
        .toast($viewModel.toast)
        .sheet(item: $viewModel.presentedSheet) { sheet in
            switch sheet {
            case .planMeal(let request):
                PlanMealSheet(viewModel: Assembly.makePlanMealViewModel(request: request, container: container))
            case .edit:
                RecipeEditorSheet(
                    viewModel: Assembly.makeRecipeEditorViewModel(recipeID: viewModel.recipeID, container: container)
                )
            }
        }
        .task { await viewModel.send(.appeared) }
    }

    private func content(_ detail: RecipeDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RecipeHero(recipe: detail.recipe)
                VStack(alignment: .leading, spacing: KodaSpacing.l - 2) {
                    HStack(spacing: KodaSpacing.xs) {
                        StatPill(value: "\(viewModel.stats.timesEaten)", captionKey: "recipe.stats.times")
                        StatPill(value: sinceText, captionKey: "recipe.stats.since")
                        StatPill(
                            value: detail.recipe.servings.formatted(.number.precision(.fractionLength(0...1))),
                            captionKey: "recipe.stats.servings"
                        )
                    }
                    RecipeActions(viewModel: viewModel)
                    RecipeIngredientsSection(detail: detail)
                    RecipeNotesEditor(
                        text: viewModel.notes,
                        state: viewModel.notesState,
                        onChange: { text in Task { await viewModel.send(.notesChanged(text)) } },
                        onFocusChange: { focused in Task { await viewModel.send(.notesFocusChanged(focused)) } }
                    )
                    if !detail.recipe.steps.isEmpty {
                        RecipeStepsSection(steps: detail.recipe.steps)
                    }
                }
                .padding(KodaSpacing.l - 4)
                .frame(maxWidth: KodaSize.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, KodaSpacing.xl * 2)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var sinceText: String {
        guard let days = viewModel.stats.daysSinceLastEaten(today: viewModel.today) else { return "—" }
        return String(localized: "recipe.stats.days \(days)")
    }
}

/// "Al planning · A la compra · La comimos".
private struct RecipeActions: View {
    let viewModel: RecipeDetailViewModel

    var body: some View {
        HStack(spacing: KodaSpacing.xs) {
            action(
                "recipe.action.plan",
                systemImage: "calendar.badge.plus",
                fill: KodaColor.brand,
                foreground: KodaColor.cream
            ) {
                Task { await viewModel.send(.planMeal) }
            }
            .accessibilityIdentifier("recipe-plan")
            action(
                "recipe.action.shopping",
                systemImage: "bag.badge.plus",
                fill: KodaColor.inverse,
                foreground: KodaColor.onInverse
            ) {
                Task { await viewModel.send(.addToShopping) }
            }
            .accessibilityIdentifier("recipe-add-to-shopping")
            action(
                "recipe.action.eaten",
                systemImage: "checkmark.circle",
                fill: KodaColor.surface,
                foreground: KodaColor.brandText
            ) {
                Task { await viewModel.send(.logConsumption) }
            }
            .accessibilityIdentifier("recipe-log")
        }
    }

    private func action(
        _ key: LocalizedStringKey,
        systemImage: String,
        fill: Color,
        foreground: Color,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            VStack(spacing: KodaSpacing.xs - 2) {
                Image(systemName: systemImage).font(.title3)
                Text(key).font(KodaTypography.footnote.weight(.bold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(fill, in: RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous))
            .overlay {
                if fill == KodaColor.surface {
                    RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous)
                        .strokeBorder(KodaColor.brand.opacity(0.25))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: KodaRadius.medium))
        }
        .buttonStyle(.plain)
    }
}

/// "Ingredientes" with quantities and the included sub-recipes ("INCLUYE LA RECETA").
private struct RecipeIngredientsSection: View {
    let detail: RecipeDetail
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s - 2) {
            SectionHeader(titleKey: "recipe.ingredients")
            VStack(spacing: 0) {
                if detail.ingredients.isEmpty, detail.components.isEmpty {
                    Text("recipe.ingredients.empty")
                        .font(KodaTypography.callout)
                        .foregroundStyle(KodaColor.textSecondary)
                        .padding(KodaSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(detail.ingredients) { ingredient in
                    HStack {
                        Text(verbatim: ingredient.productName)
                            .font(KodaTypography.body.weight(.semibold))
                        Spacer()
                        let quantity = KodaFormat.quantity(ingredient.quantity, unit: ingredient.unit, locale: locale)
                        Text(quantity.isEmpty ? String(localized: "recipe.ingredients.no-quantity") : quantity)
                            .font(KodaTypography.body)
                            .foregroundStyle(quantity.isEmpty ? KodaColor.textTertiary : KodaColor.textSecondary)
                    }
                    .padding(.horizontal, KodaSpacing.m)
                    .padding(.vertical, KodaSpacing.s + 1)
                    Divider().overlay(KodaColor.background)
                }
                ForEach(detail.components) { component in
                    NavigationLink(value: AppRoute.recipe(id: component.childRecipeID)) {
                        HStack(spacing: KodaSpacing.s) {
                            Image(systemName: "book.closed")
                                .foregroundStyle(KodaColor.brandText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("recipe.includes").kodaEyebrow()
                                Text(verbatim: component.childRecipeName)
                                    .font(KodaTypography.body.weight(.bold))
                                    .foregroundStyle(KodaColor.walnutDeep)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(KodaColor.brandText)
                        }
                        .padding(.horizontal, KodaSpacing.m)
                        .padding(.vertical, KodaSpacing.s + 1)
                        .background(KodaColor.chip)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recipe-component-\(component.childRecipeID)")
                }
            }
            .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
        }
    }
}

/// "Pasos", numbered.
private struct RecipeStepsSection: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            SectionHeader(titleKey: "recipe.steps")
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: KodaSpacing.s + 2) {
                    Text(verbatim: "\(index + 1)")
                        .font(KodaTypography.subheadline.weight(.heavy))
                        .foregroundStyle(KodaColor.cream)
                        .frame(width: 30, height: 30)
                        .background(KodaColor.brand, in: Circle())
                        .accessibilityHidden(true)
                    Text(verbatim: step)
                        .font(KodaTypography.body)
                        .foregroundStyle(KodaColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Recipe detail · iPhone") {
        RecipesPreviewFactory.makeRecipeDetailView()
            .kodaPreview()
    }

    #Preview("Recipe detail · dark") {
        RecipesPreviewFactory.makeRecipeDetailView()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Recipe detail · missing") {
        RecipesPreviewFactory.makeRecipeDetailView(recipeID: UUID())
            .kodaPreview()
    }

    #Preview("Recipe detail · Mac", traits: .fixedLayout(width: 1000, height: 800)) {
        RecipesPreviewFactory.makeRecipeDetailView()
            .kodaPreview()
    }
#endif
