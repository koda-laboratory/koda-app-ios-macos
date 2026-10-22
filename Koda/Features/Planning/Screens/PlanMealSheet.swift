import SwiftUI

/// Plan a meal, or change, move or remove a planned one.
struct PlanMealSheet: View {
    @State private var viewModel: PlanMealViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PlanMealViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("plan-meal.day", selection: $viewModel.form.day.date, displayedComponents: .date)
                        .accessibilityIdentifier("plan-meal-day")
                    Picker("plan-meal.slot", selection: $viewModel.form.slot) {
                        ForEach(MealSlot.allCases, id: \.self) { slot in
                            Text(slot.titleKey).tag(slot)
                        }
                    }
                    .accessibilityIdentifier("plan-meal-slot")
                }

                Section {
                    Picker("plan-meal.kind", selection: $viewModel.form.kind) {
                        Text("plan-meal.kind.recipe").tag(PlanMealFormState.Kind.recipe)
                        Text("plan-meal.kind.text").tag(PlanMealFormState.Kind.text)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if viewModel.form.kind == .text {
                        TextField("plan-meal.text.placeholder", text: $viewModel.form.freeText)
                            .submitLabel(.done)
                            .onSubmit { Task { await viewModel.send(.save) } }
                            .accessibilityIdentifier("plan-meal-text")
                        if viewModel.showsTextError {
                            Text("plan-meal.text.missing").font(KodaTypography.caption).foregroundStyle(KodaColor.error)
                        }
                    } else {
                        PlanMealRecipePicker(viewModel: viewModel)
                    }
                } header: {
                    Text("plan-meal.what")
                }

                Section {
                    Toggle("plan-meal.custom-time", isOn: $viewModel.form.usesCustomTime)
                    if viewModel.form.usesCustomTime {
                        DatePicker(
                            "plan-meal.time",
                            selection: $viewModel.form.time.date,
                            displayedComponents: .hourAndMinute
                        )
                    } else {
                        LabeledContent("plan-meal.time") {
                            Text(verbatim: viewModel.defaultTime.description)
                        }
                    }
                    if viewModel.form.kind == .recipe {
                        Stepper(value: $viewModel.form.servings, in: 1...12, step: 1) {
                            Text("plan-meal.servings \(Int(viewModel.form.servings))")
                        }
                    }
                } footer: {
                    Text("plan-meal.time.footer")
                }

                if viewModel.isEditing {
                    Section {
                        Button("plan-meal.remove", role: .destructive) {
                            Task { await viewModel.send(.delete) }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(KodaColor.background)
            .navigationTitle(Text(viewModel.isEditing ? "plan-meal.title.edit" : "plan-meal.title.new"))
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { Task { await viewModel.send(.save) } }
                        .disabled(viewModel.state.isSaving)
                        .accessibilityIdentifier("plan-meal-save")
                }
            }
            .toast($viewModel.toast)
        }
        .dismissKeyboard()
        .keyboardMargin()
        .presentationDetents([.large])
        .platformSheetSize()
        .task { await viewModel.send(.appeared) }
        .onChange(of: viewModel.state) {
            if viewModel.state == .completed { dismiss() }
        }
    }
}

/// Searchable recipe list inside the plan-meal form.
private struct PlanMealRecipePicker: View {
    @Bindable var viewModel: PlanMealViewModel

    var body: some View {
        TextField("plan-meal.search", text: $viewModel.searchText)
            .accessibilityIdentifier("plan-meal-search")
        if viewModel.showsRecipeError {
            Text("plan-meal.recipe.missing").font(KodaTypography.caption).foregroundStyle(KodaColor.error)
        }
        ForEach(viewModel.filteredRecipes.prefix(40)) { item in
            Button {
                Task { await viewModel.send(.selectRecipe(item.id)) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: item.recipe.name)
                            .foregroundStyle(KodaColor.textPrimary)
                        if let minutes = item.recipe.timeMinutes {
                            Text("recipe.minutes \(minutes)")
                                .font(KodaTypography.caption)
                                .foregroundStyle(KodaColor.textSecondary)
                        }
                    }
                    Spacer()
                    if viewModel.form.recipeID == item.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(KodaColor.brandText)
                            .symbolEffect(.bounce, value: viewModel.form.recipeID)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(viewModel.form.recipeID == item.id ? .isSelected : [])
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Plan meal · new") {
        PlanMealSheet(viewModel: PlanningPreviewFactory.makePlanMealViewModel())
            .kodaPreview()
    }

    #Preview("Plan meal · dark") {
        PlanMealSheet(viewModel: PlanningPreviewFactory.makePlanMealViewModel())
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Plan meal · Mac", traits: .fixedLayout(width: 560, height: 680)) {
        PlanMealSheet(viewModel: PlanningPreviewFactory.makePlanMealViewModel())
            .kodaPreview()
    }
#endif
