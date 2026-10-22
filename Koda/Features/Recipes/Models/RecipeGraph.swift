import Foundation

/// Snapshot of every live recipe, ingredient and component, used to expand nested recipes locally.
struct RecipeGraph: Sendable, Equatable {
    struct Node: Sendable, Equatable {
        let id: UUID
        let name: String
        let servings: Double
    }

    struct Ingredient: Sendable, Equatable {
        let productID: UUID
        let productName: String
        let quantity: Double?
        let unit: String?
        let position: Int
    }

    struct Component: Sendable, Equatable {
        let childRecipeID: UUID
        let servingsFactor: Double
        let position: Int
    }

    var recipes: [UUID: Node]
    var ingredients: [UUID: [Ingredient]]
    var components: [UUID: [Component]]

    init(
        recipes: [UUID: Node] = [:],
        ingredients: [UUID: [Ingredient]] = [:],
        components: [UUID: [Component]] = [:]
    ) {
        self.recipes = recipes
        self.ingredients = ingredients
        self.components = components
    }
}

/// A recipe expanded with its sub-recipes: the tree and the products aggregated by product and unit.
struct RecipeExpansion: Sendable, Equatable {
    struct TreeNode: Sendable, Equatable {
        let recipeID: UUID
        let parentRecipeID: UUID?
        let name: String
        let depth: Int
        /// Product of the `servings_factor` along the path from the root.
        let servingsFactor: Double
    }

    struct Item: Sendable, Equatable {
        let productID: UUID
        let productName: String
        let unit: String?
        /// `nil` when no ingredient of this product and unit has a quantity.
        let quantity: Double?
        let recipeIDs: Set<UUID>
    }

    let recipeID: UUID
    /// Requested servings (`nil` = as written).
    let servings: Double?
    let tree: [TreeNode]
    let items: [Item]

    /// "Pollo al horno + Patatas al airfryer".
    var label: String {
        tree.map(\.name).joined(separator: " + ")
    }
}
