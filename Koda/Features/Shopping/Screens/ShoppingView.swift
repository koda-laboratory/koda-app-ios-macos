import SwiftUI

/// Compra (approved mockup `Shopping`): one continuous list with three states per product.
struct ShoppingView: View {
    @State private var viewModel: ShoppingViewModel
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    @FocusState private var isQuickAddFocused: Bool
    @State private var isSharedExpanded = true

    init(viewModel: ShoppingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let layout = viewModel.layout(
            categoryTitle: { String(localized: $0.titleResource).uppercased(with: locale) },
            otherTitle: String(localized: "shopping.group.other").uppercased(with: locale),
            quantity: { KodaFormat.quantity($0, unit: $1, locale: locale) }
        )
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KodaSpacing.m) {
                ScreenHeader(
                    subtitle: String(localized: "shopping.pending \(layout.pendingCount)"),
                    title: String(localized: "tab.shopping")
                ) { EmptyView() }
                ShoppingCycleCard(title: cycleTitle, subtitle: cycleSubtitle) {
                    router.selectedTab = .planning
                }
                ShoppingQuickAdd(viewModel: viewModel, focus: $isQuickAddFocused)

                if viewModel.state == .ready, layout.isEmpty {
                    EmptyStateView(titleKey: "shopping.empty.title", messageKey: "shopping.empty.message")
                }

                if !layout.sharedRows.isEmpty {
                    ShoppingRecipeEntryCard(
                        title: String(localized: "shopping.shared.title"),
                        subtitle: String(
                            localized:
                                "shopping.recipe.left \(layout.sharedRows.filter { $0.status == .pending }.count)"
                        ),
                        systemImage: "square.stack",
                        isExpanded: isSharedExpanded,
                        rows: layout.sharedRows,
                        showsRecipes: true,
                        onToggleExpanded: { withAnimation { isSharedExpanded.toggle() } },
                        onToggleHave: { row in Task { await viewModel.send(.toggleHave(row)) } },
                        onToggleFrozen: { row in Task { await viewModel.send(.toggleFrozen(row)) } }
                    )
                    .accessibilityIdentifier("shopping-shared")
                }

                ForEach(layout.recipeEntries) { entry in
                    ShoppingRecipeEntryCard(
                        title: entry.title,
                        subtitle: recipeSubtitle(entry),
                        isExpanded: viewModel.expandedEntryIDs.contains(entry.id),
                        rows: recipeRows(entry, layout: layout),
                        onToggleExpanded: { Task { await viewModel.send(.toggleExpanded(entry.id)) } },
                        onToggleHave: { row in Task { await viewModel.send(.toggleHave(row)) } },
                        onToggleFrozen: { row in Task { await viewModel.send(.toggleFrozen(row)) } },
                        onRemove: {
                            let row = ShoppingRow(
                                source: .entry(entry.id),
                                title: entry.title,
                                quantityText: "",
                                status: entry.status,
                                category: nil,
                                storeNames: [],
                                isText: false,
                                recipeTitle: nil
                            )
                            Task { await viewModel.send(.removeRow(row)) }
                        }
                    )
                    .accessibilityIdentifier("shopping-recipe-\(entry.id)")
                }

                ForEach(layout.pendingGroups) { group in
                    VStack(alignment: .leading, spacing: KodaSpacing.xs) {
                        ListLabel(text: group.title)
                        ShoppingRowsCard(rows: group.rows, viewModel: viewModel) { row in
                            meta(for: row)
                        }
                    }
                }

                if !layout.frozenRows.isEmpty {
                    ShoppingFrozenSection(rows: layout.frozenRows, viewModel: viewModel, slotTimes: slotTimes)
                }

                if !layout.haveRows.isEmpty {
                    VStack(alignment: .leading, spacing: KodaSpacing.xs) {
                        ListLabel(
                            text: String(localized: "shopping.have.title \(layout.haveRows.count)").uppercased(
                                with: locale
                            ),
                            actionKey: "shopping.clear-have"
                        ) {
                            Task { await viewModel.send(.clearHave) }
                        }
                        ShoppingRowsCard(rows: layout.haveRows, viewModel: viewModel, dimmed: true) { _ in "" }
                    }
                }
            }
            .padding(.horizontal, KodaSpacing.l - 4)
            .padding(.top, KodaSpacing.s)
            .padding(.bottom, KodaSpacing.xl * 3)
            .frame(maxWidth: KodaSize.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(KodaColor.background)
        .navigationTitle(Text("tab.shopping"))
        .platformHidesNavigationBar()
        .dismissKeyboard()
        .keyboardMargin()
        .toast($viewModel.toast)
        .sheet(item: $viewModel.presentedSheet) { _ in
            NotificationsExplanationSheet(
                onEnable: { Task { await viewModel.send(.enableNotifications) } },
                onLater: { Task { await viewModel.send(.dismissSheet) } }
            )
        }
        .task { await viewModel.send(.appeared) }
        .onChange(of: router.pendingAction, initial: true) {
            if router.consume(.addToShopping) {
                isQuickAddFocused = true
            }
        }
    }

    private var slotTimes: SlotTimes { viewModel.household?.household.settings.slotTimes ?? .default }

    private var cycleTitle: String {
        String(
            localized: "shopping.cycle.title \(KodaFormat.weekdayAndDay(viewModel.cycle.shoppingDay, locale: locale))"
        )
    }

    private var cycleSubtitle: String {
        String(
            localized:
                "shopping.cycle.subtitle \(KodaFormat.shortDay(viewModel.cycle.from, locale: locale)) \(KodaFormat.shortDay(viewModel.cycle.through, locale: locale))"
        )
    }

    private func meta(for row: ShoppingRow) -> String {
        KodaFormat.joined([
            row.isText ? String(localized: "shopping.free-text") : row.quantityText, row.storeNames.first,
        ])
    }

    private func recipeRows(_ entry: ShoppingEntry, layout: ShoppingLayout) -> [ShoppingRow] {
        entry.items.map { item in
            ShoppingRow(
                source: .item(entryID: entry.id, itemID: item.id),
                title: item.productName,
                quantityText: KodaFormat.quantity(item.quantity, unit: item.unit, locale: locale),
                status: item.status,
                category: item.category,
                storeNames: item.storeNames,
                isText: false,
                recipeTitle: entry.title
            )
        }
    }

    private func recipeSubtitle(_ entry: ShoppingEntry) -> String {
        let left = String(localized: "shopping.recipe.left \(entry.pendingItemCount)")
        let frozen =
            entry.frozenItemCount > 0 ? String(localized: "shopping.recipe.frozen \(entry.frozenItemCount)") : nil
        return KodaFormat.joined([left, frozen])
    }
}

/// The quick-add field with product and recipe autocomplete.
private struct ShoppingQuickAdd: View {
    @Bindable var viewModel: ShoppingViewModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.xs) {
            QuickAddField(placeholderKey: "shopping.add.placeholder", text: $viewModel.quickAddText, focus: focus) {
                Task { await viewModel.send(.submitQuickAdd) }
            }
            let suggestions = viewModel.suggestions
            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            Task { await viewModel.send(.pickSuggestion(suggestion)) }
                        } label: {
                            SuggestionLabel(suggestion: suggestion)
                        }
                        .buttonStyle(.plain)
                        if suggestion != suggestions.last {
                            Divider().overlay(KodaColor.chip)
                        }
                    }
                }
                .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaSpacing.m, style: .continuous))
            } else {
                Text("shopping.add.help")
                    .font(KodaTypography.caption)
                    .foregroundStyle(KodaColor.textSecondary)
                    .padding(.horizontal, KodaSpacing.xxs)
            }
        }
    }
}

private struct SuggestionLabel: View {
    let suggestion: ShoppingSuggestion

    var body: some View {
        HStack(spacing: KodaSpacing.s - 2) {
            Image(systemName: icon)
                .foregroundStyle(KodaColor.brandText)
                .frame(width: 24)
            switch suggestion {
            case .product(let product):
                Text(verbatim: product.name)
            case .recipe(let recipe):
                Text("shopping.add.recipe \(recipe.name)")
            case .text(let text):
                Text("shopping.add.text \(text)")
            }
            Spacer()
        }
        .font(KodaTypography.body)
        .foregroundStyle(KodaColor.textPrimary)
        .padding(.horizontal, KodaSpacing.s + 2)
        .padding(.vertical, KodaSpacing.s - 2)
        .contentShape(Rectangle())
    }

    private var icon: String {
        switch suggestion {
        case .product: "basket"
        case .recipe: "book.closed"
        case .text: "text.cursor"
        }
    }
}

/// A white card of product rows.
private struct ShoppingRowsCard: View {
    let rows: [ShoppingRow]
    let viewModel: ShoppingViewModel
    var dimmed = false
    let meta: (ShoppingRow) -> String

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                ShoppingRowView(
                    row: row,
                    meta: meta(row),
                    onToggleHave: { Task { await viewModel.send(.toggleHave(row)) } },
                    onToggleFrozen: { Task { await viewModel.send(.toggleFrozen(row)) } }
                )
                .contextMenu {
                    if case .entry = row.source {
                        Button("shopping.remove", systemImage: "trash", role: .destructive) {
                            Task { await viewModel.send(.removeRow(row)) }
                        }
                    }
                }
                if row.id != rows.last?.id {
                    Divider().overlay(KodaColor.background)
                }
            }
        }
        .background(
            dimmed ? KodaColor.surface.opacity(0.55) : KodaColor.surface,
            in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous)
        )
    }
}

/// "EN EL CONGELADOR": what is frozen, the meal it is for and when the reminder comes.
private struct ShoppingFrozenSection: View {
    let rows: [ShoppingRow]
    let viewModel: ShoppingViewModel
    let slotTimes: SlotTimes
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.xs) {
            ListLabel(text: String(localized: "shopping.frozen.title \(rows.count)").uppercased(with: locale))
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(spacing: KodaSpacing.s) {
                        Image(systemName: "snowflake")
                            .foregroundStyle(KodaColor.taupe)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: row.title)
                                .font(KodaTypography.body.weight(.bold))
                            Text(verbatim: mealText(row))
                                .font(KodaTypography.caption)
                                .foregroundStyle(KodaColor.taupeLight)
                            Text(verbatim: reminderText(row))
                                .font(KodaTypography.caption.weight(.bold))
                                .foregroundStyle(KodaColor.taupe)
                        }
                        Spacer(minLength: 0)
                        Button("shopping.frozen.remove") {
                            Task { await viewModel.send(.toggleFrozen(row)) }
                        }
                        .font(KodaTypography.caption.weight(.semibold))
                        .foregroundStyle(KodaColor.cream)
                        .padding(.horizontal, KodaSpacing.s)
                        .frame(minHeight: KodaSize.chipHeight - 2)
                        .overlay { Capsule().strokeBorder(KodaColor.taupe.opacity(0.4)) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("frozen-remove-\(row.id)")
                    }
                    .foregroundStyle(KodaColor.cream)
                    .padding(.leading, KodaSpacing.m)
                    .padding(.trailing, KodaSpacing.xs)
                    .padding(.vertical, KodaSpacing.s + 2)
                    if row.id != rows.last?.id {
                        Divider().overlay(KodaColor.taupe.opacity(0.15))
                    }
                }
            }
            .background(KodaColor.onyx, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
        }
    }

    private func mealText(_ row: ShoppingRow) -> String {
        // One product frozen for several recipes lists them all.
        if case .shared = row.source, let recipes = row.recipeTitle {
            return String(localized: "shopping.frozen.for-recipe \(recipes)")
        }
        if let meal = row.frozenItem?.meal, let recipe = meal.recipeName {
            let day = KodaFormat.shortDay(meal.day, locale: locale)
            let slot = String(localized: meal.slot.titleResource).lowercased()
            return String(localized: "shopping.frozen.for \(recipe) \(day) \(slot)")
        }
        if let recipe = row.recipeTitle {
            return String(localized: "shopping.frozen.for-recipe \(recipe)")
        }
        return row.frozenItem == nil
            ? String(localized: "shopping.frozen.pending-sync")
            : String(localized: "shopping.frozen.not-planned")
    }

    private func reminderText(_ row: ShoppingRow) -> String {
        guard let remindAt = row.frozenItem?.defrostRemindAt else {
            return String(localized: "shopping.frozen.reminder-unknown")
        }
        let text = remindAt.formatted(.dateTime.weekday(.abbreviated).day().hour().minute().locale(locale))
        return String(localized: "shopping.frozen.reminder \(text)")
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Shopping · iPhone") {
        ShoppingPreviewFactory.makeShoppingView()
            .kodaPreview()
    }

    #Preview("Shopping · empty") {
        ShoppingPreviewFactory.makeShoppingView(container: PreviewContainer.empty)
            .kodaPreview()
    }

    #Preview("Shopping · dark") {
        ShoppingPreviewFactory.makeShoppingView()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Shopping · Mac", traits: .fixedLayout(width: 1100, height: 800)) {
        ShoppingPreviewFactory.makeShoppingView()
            .kodaPreview()
    }
#endif
