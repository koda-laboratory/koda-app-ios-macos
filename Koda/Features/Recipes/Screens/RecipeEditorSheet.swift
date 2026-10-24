import SwiftUI

/// Recipe editor: name, meal types, nutrients, time, servings, ingredients, "Incluir otra receta" and
/// reorderable steps.
struct RecipeEditorSheet: View {
    @State private var viewModel: RecipeEditorViewModel
    @State private var picker: EditorPicker?
    @Environment(\.dismiss) private var dismiss

    /// Component-local nested pickers.
    private enum EditorPicker: String, Identifiable {
        case product
        case recipe

        var id: String { rawValue }
    }

    init(viewModel: RecipeEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("recipe-editor.name", text: $viewModel.form.name)
                        .font(KodaTypography.headline)
                        .accessibilityIdentifier("recipe-editor-name")
                    if viewModel.showsNameError {
                        Text("recipe-editor.name.missing").font(KodaTypography.caption).foregroundStyle(KodaColor.error)
                    }
                    HStack {
                        Text("recipe-editor.time")
                        Spacer()
                        TextField("recipe-editor.time.placeholder", text: $viewModel.form.timeText)
                            .platformNumberField()
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                        Text("recipe-editor.minutes").foregroundStyle(KodaColor.textSecondary)
                    }
                    Stepper(value: $viewModel.form.servings, in: 1...20, step: 1) {
                        Text("recipe-editor.servings \(Int(viewModel.form.servings))")
                    }
                    Toggle("recipe-editor.favorite", isOn: $viewModel.form.isFavorite)
                }

                Section("recipe-editor.meal-types") {
                    ChipGrid(
                        items: MealSlot.allCases,
                        isSelected: { viewModel.form.mealTypes.contains($0) },
                        title: \.titleKey,
                        toggle: { slot in
                            viewModel.form.mealTypes.formSymmetricDifference([slot])
                        }
                    )
                }

                Section("recipe-editor.nutrients") {
                    ChipGrid(
                        items: Nutrient.allCases,
                        isSelected: { viewModel.form.nutrients.contains($0) },
                        title: \.titleKey,
                        toggle: { nutrient in
                            viewModel.form.nutrients.formSymmetricDifference([nutrient])
                        }
                    )
                }

                Section("recipe.ingredients") {
                    ForEach($viewModel.form.ingredients) { $row in
                        HStack {
                            Text(verbatim: row.productName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            TextField("recipe-editor.quantity", text: $row.quantityText)
                                .platformDecimalField()
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 70)
                                .foregroundStyle(row.isQuantityValid ? KodaColor.textPrimary : KodaColor.error)
                            TextField("recipe-editor.unit", text: $row.unit)
                                .frame(maxWidth: 70)
                        }
                    }
                    .onDelete { offsets in Task { await viewModel.send(.removeIngredients(offsets)) } }
                    Button("recipe-editor.add-ingredient", systemImage: "plus.circle") { picker = .product }
                        .accessibilityIdentifier("recipe-editor-add-ingredient")
                }

                Section {
                    ForEach($viewModel.form.components) { $row in
                        Stepper(value: $row.servingsFactor, in: 0.5...4, step: 0.5) {
                            VStack(alignment: .leading) {
                                Text(verbatim: row.name)
                                Text(
                                    "recipe-editor.factor \(row.servingsFactor.formatted(.number.precision(.fractionLength(0...1))))"
                                )
                                .font(KodaTypography.caption)
                                .foregroundStyle(KodaColor.textSecondary)
                            }
                        }
                    }
                    .onDelete { offsets in Task { await viewModel.send(.removeComponents(offsets)) } }
                    Button("recipe-editor.include-recipe", systemImage: "book.closed") { picker = .recipe }
                        .accessibilityIdentifier("recipe-editor-include")
                } header: {
                    Text("recipe-editor.sub-recipes")
                }

                Section {
                    ForEach($viewModel.form.steps) { $step in
                        TextField("recipe-editor.step", text: $step.text, axis: .vertical)
                    }
                    .onDelete { offsets in Task { await viewModel.send(.removeSteps(offsets)) } }
                    .onMove { offsets, destination in Task { await viewModel.send(.moveSteps(offsets, destination)) } }
                    Button("recipe-editor.add-step", systemImage: "plus.circle") {
                        Task { await viewModel.send(.addStep) }
                    }
                } header: {
                    Text("recipe.steps")
                } footer: {
                    Text("recipe-editor.steps.footer")
                }

                if viewModel.isEditing {
                    Section {
                        Button("recipe-editor.delete", role: .destructive) {
                            Task { await viewModel.send(.delete) }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(KodaColor.background)
            .disabled(viewModel.state == .loading)
            .navigationTitle(Text(viewModel.isEditing ? "recipe-editor.title.edit" : "recipe-editor.title.new"))
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { Task { await viewModel.send(.save) } }
                        .disabled(viewModel.state.isBusy)
                        .accessibilityIdentifier("recipe-editor-save")
                }
            }
            .toast($viewModel.toast)
            .sheet(item: $picker) { picker in
                switch picker {
                case .product:
                    SearchPickerSheet(
                        titleKey: "recipe-editor.pick-product",
                        emptyTitleKey: "products.empty.title",
                        items: viewModel.products.map { ($0.id, $0.name) }
                    ) { id in
                        if let product = viewModel.products.first(where: { $0.id == id }) {
                            Task { await viewModel.send(.addIngredient(product)) }
                        }
                    }
                case .recipe:
                    SearchPickerSheet(
                        titleKey: "recipe-editor.pick-recipe",
                        emptyTitleKey: "recipes.empty.title",
                        items: viewModel.includableRecipes.map { ($0.id, $0.name) }
                    ) { id in
                        if let recipe = viewModel.includableRecipes.first(where: { $0.id == id }) {
                            Task { await viewModel.send(.addComponent(recipe)) }
                        }
                    }
                }
            }
        }
        .dismissKeyboard()
        .keyboardMargin()
        .presentationDetents([.large])
        .platformSheetSize(width: 600, height: 760)
        .task { await viewModel.send(.appeared) }
        .platformHaptic(trigger: viewModel.state) { _, state in
            switch state {
            case .completed: .success
            case .deleted: .impact(weight: .medium)
            default: nil
            }
        }
        .onChange(of: viewModel.state) {
            if viewModel.state == .completed || viewModel.state == .deleted { dismiss() }
        }
    }
}

/// Wrapping selectable chips inside a form row.
private struct ChipGrid<Item: Hashable>: View {
    let items: [Item]
    let isSelected: (Item) -> Bool
    let title: KeyPath<Item, LocalizedStringKey>
    let toggle: (Item) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), spacing: KodaSpacing.xs)],
            alignment: .leading,
            spacing: KodaSpacing.xs
        ) {
            ForEach(items, id: \.self) { item in
                ChipView(titleKey: item[keyPath: title], isSelected: isSelected(item)) { toggle(item) }
            }
        }
        .padding(.vertical, KodaSpacing.xxs)
    }
}

/// A searchable list that returns one id (products for ingredients, recipes to include).
struct SearchPickerSheet: View {
    let titleKey: LocalizedStringKey
    /// Shown when there is nothing to pick from at all.
    let emptyTitleKey: LocalizedStringKey
    let items: [(UUID, String)]
    let onPick: (UUID) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \.0) { item in
                    Button(item.1) {
                        onPick(item.0)
                        dismiss()
                    }
                    .foregroundStyle(KodaColor.textPrimary)
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(emptyTitleKey, systemImage: "tray")
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query)
            .navigationTitle(Text(titleKey))
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
        .platformSheetSize(width: 420, height: 560)
    }

    private var filtered: [(UUID, String)] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? items : items.filter { $0.1.localizedStandardContains(trimmed) }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Recipe editor · edit") {
        RecipeEditorSheet(viewModel: RecipesPreviewFactory.makeRecipeEditorViewModel())
            .kodaPreview()
    }

    #Preview("Recipe editor · new") {
        RecipeEditorSheet(viewModel: RecipesPreviewFactory.makeRecipeEditorViewModel(recipeID: nil))
            .kodaPreview()
    }

    #Preview("Recipe editor · dark") {
        RecipeEditorSheet(viewModel: RecipesPreviewFactory.makeRecipeEditorViewModel())
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Recipe editor · Mac", traits: .fixedLayout(width: 600, height: 760)) {
        RecipeEditorSheet(viewModel: RecipesPreviewFactory.makeRecipeEditorViewModel())
            .kodaPreview()
    }
#endif
