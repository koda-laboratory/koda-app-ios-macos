import Foundation
import Observation

enum RecipeEditorState: Sendable, Equatable {
    case loading
    case idle
    case invalidForm
    case saving
    case completed
    case deleted

    var isBusy: Bool { self == .loading || self == .saving }
}

enum RecipeEditorIntent: Sendable {
    case appeared
    case addIngredient(Product)
    case removeIngredients(IndexSet)
    case addComponent(Recipe)
    case removeComponents(IndexSet)
    case addStep
    case removeSteps(IndexSet)
    case moveSteps(IndexSet, Int)
    case save
    case delete
}

/// Creates or edits a recipe with its ingredients, sub-recipes ("Incluir otra receta") and steps.
@MainActor
@Observable
final class RecipeEditorViewModel: FormViewModel {
    /// The use cases the editor depends on.
    struct UseCases {
        let observeDetail: any ObserveRecipeDetailUseCase
        let observeProducts: any ObserveProductsUseCase
        let observeCatalog: any ObserveRecipeCatalogUseCase
        let saveRecipe: any SaveRecipeWithContentsUseCase
        let deleteRecipe: any DeleteRecipeUseCase
    }

    // MARK: - Properties

    let recipeID: UUID?
    private(set) var state: RecipeEditorState
    private(set) var products: [Product] = []
    private(set) var recipes: [Recipe] = []
    var form = RecipeEditorFormState()
    var toast: Toast?

    @ObservationIgnored private let useCases: UseCases
    @ObservationIgnored private var observations: [Task<Void, Never>]?

    // MARK: - Lifecycle

    init(recipeID: UUID?, useCases: UseCases) {
        self.recipeID = recipeID
        self.useCases = useCases
        self.state = recipeID == nil ? .idle : .loading
    }

    deinit {
        observations?.forEach { $0.cancel() }
    }

    // MARK: - Derived

    var isEditing: Bool { recipeID != nil }
    var showsNameError: Bool { state == .invalidForm && form.trimmedName.isEmpty }

    /// Recipes that can be included (not itself, not already included).
    var includableRecipes: [Recipe] {
        let included = Set(form.components.map(\.childRecipeID))
        return recipes.filter { $0.id != recipeID && !included.contains($0.id) }
    }

    // MARK: - Intents

    func send(_ intent: RecipeEditorIntent) async {
        switch intent {
        case .appeared:
            await start()
        case .addIngredient(let product):
            form.ingredients.append(
                .init(
                    id: UUID(),
                    ingredientID: nil,
                    productID: product.id,
                    productName: product.name,
                    quantityText: "",
                    unit: product.defaultUnit ?? ""
                )
            )
        case .removeIngredients(let offsets):
            form.ingredients.remove(atOffsets: offsets)
        case .addComponent(let recipe):
            form.components.append(
                .init(id: UUID(), componentID: nil, childRecipeID: recipe.id, name: recipe.name, servingsFactor: 1)
            )
        case .removeComponents(let offsets):
            form.components.remove(atOffsets: offsets)
        case .addStep:
            form.steps.append(.init(id: UUID(), text: ""))
        case .removeSteps(let offsets):
            form.steps.remove(atOffsets: offsets)
        case .moveSteps(let offsets, let destination):
            form.steps.move(fromOffsets: offsets, toOffset: destination)
        case .save:
            await save()
        case .delete:
            await delete()
        }
    }

    // MARK: - Private Methods

    private func start() async {
        if observations == nil {
            let products = useCases.observeProducts.execute()
            let catalog = useCases.observeCatalog.execute()
            observations = [
                Task { [weak self] in
                    for await items in products { self?.products = items }
                },
                Task { [weak self] in
                    for await items in catalog { self?.recipes = items.map(\.recipe) }
                },
            ]
        }
        guard state == .loading, let recipeID else { return }
        for await detail in useCases.observeDetail.execute(recipeID: recipeID) {
            if let detail { fill(from: detail) }
            break
        }
        state = .idle
    }

    private func fill(from detail: RecipeDetail) {
        let recipe = detail.recipe
        form = RecipeEditorFormState(
            name: recipe.name,
            emoji: recipe.emoji ?? "",
            mealTypes: Set(recipe.mealTypes),
            nutrients: Set(recipe.nutrients),
            timeText: recipe.timeMinutes.map(String.init) ?? "",
            servings: recipe.servings,
            isFavorite: recipe.isFavorite,
            notes: recipe.notes,
            ingredients: detail.ingredients.map { ingredient in
                .init(
                    id: UUID(),
                    ingredientID: ingredient.id,
                    productID: ingredient.productID,
                    productName: ingredient.productName,
                    quantityText: ingredient.quantity.map { $0.formatted(.number.precision(.fractionLength(0...2))) }
                        ?? "",
                    unit: ingredient.unit ?? ""
                )
            },
            components: detail.components.map { component in
                .init(
                    id: UUID(),
                    componentID: component.id,
                    childRecipeID: component.childRecipeID,
                    name: component.childRecipeName,
                    servingsFactor: component.servingsFactor
                )
            },
            steps: recipe.steps.map { .init(id: UUID(), text: $0) }
        )
    }

    private func save() async {
        guard !state.isBusy else { return }
        guard form.isValid else {
            state = .invalidForm
            return
        }
        state = .saving
        do {
            try await useCases.saveRecipe.execute(
                form.input(id: recipeID),
                ingredients: form.ingredientDrafts,
                components: form.componentDrafts
            )
            state = .completed
        } catch {
            state = .idle
            toast = .error(error)
        }
    }

    private func delete() async {
        guard let recipeID, !state.isBusy else { return }
        state = .saving
        do {
            try await useCases.deleteRecipe.execute(recipeID: recipeID)
            state = .deleted
        } catch {
            state = .idle
            toast = .error(error)
        }
    }
}
