import Foundation

/// Expands nested recipes (shared by "add recipe to the shopping list", the recipe detail and intents). Mirrors
/// the backend's `recipe_tree` / `recipe_flat_ingredients`: cycle-safe by path, at most 16 levels deep,
/// quantities multiplied by the `servings_factor` along the path and by `servings / root servings`, and products
/// aggregated by `product_id + unit`.
protocol RecipeExpansionService: Sendable {
    func expand(recipeID: UUID, servings: Double?, in graph: RecipeGraph) throws(KodaError) -> RecipeExpansion
    /// `true` when making `childID` a component of `parentID` would create a cycle.
    func wouldCreateCycle(parentID: UUID, childID: UUID, in graph: RecipeGraph) -> Bool
}

final class RecipeExpansionServiceImpl: RecipeExpansionService, Sendable {
    static let maximumDepth = 16

    func expand(recipeID: UUID, servings: Double?, in graph: RecipeGraph) throws(KodaError) -> RecipeExpansion {
        guard let root = graph.recipes[recipeID] else {
            throw KodaError(type: .notFound, reason: "Recipe \(recipeID) not found.")
        }
        let scale = servings.map { root.servings > 0 ? $0 / root.servings : 1 } ?? 1

        var tree: [RecipeExpansion.TreeNode] = []
        var accumulator = ItemAccumulator()

        func visit(_ node: RecipeGraph.Node, parentID: UUID?, depth: Int, factor: Double, path: Set<UUID>) {
            tree.append(
                RecipeExpansion.TreeNode(
                    recipeID: node.id,
                    parentRecipeID: parentID,
                    name: node.name,
                    depth: depth,
                    servingsFactor: factor
                )
            )
            for ingredient in (graph.ingredients[node.id] ?? []).sorted(by: { $0.position < $1.position }) {
                accumulator.add(
                    ingredient,
                    quantity: ingredient.quantity.map { $0 * factor * scale },
                    recipeID: node.id
                )
            }
            guard depth < Self.maximumDepth else { return }
            for component in (graph.components[node.id] ?? []).sorted(by: { $0.position < $1.position }) {
                guard !path.contains(component.childRecipeID), let child = graph.recipes[component.childRecipeID]
                else { continue }
                visit(
                    child,
                    parentID: node.id,
                    depth: depth + 1,
                    factor: factor * component.servingsFactor,
                    path: path.union([child.id])
                )
            }
        }

        visit(root, parentID: nil, depth: 0, factor: 1, path: [root.id])
        return RecipeExpansion(recipeID: recipeID, servings: servings, tree: tree, items: accumulator.items)
    }

    func wouldCreateCycle(parentID: UUID, childID: UUID, in graph: RecipeGraph) -> Bool {
        guard parentID != childID else { return true }
        var stack = [childID]
        var visited: Set<UUID> = []
        while let current = stack.popLast() {
            guard visited.insert(current).inserted else { continue }
            for component in graph.components[current] ?? [] {
                if component.childRecipeID == parentID { return true }
                stack.append(component.childRecipeID)
            }
        }
        return false
    }
}

// MARK: - Aggregation

private struct ItemAccumulator {
    private struct Key: Hashable {
        let productID: UUID
        let unit: String?
    }

    private var order: [Key] = []
    private var values: [Key: RecipeExpansion.Item] = [:]

    mutating func add(_ ingredient: RecipeGraph.Ingredient, quantity: Double?, recipeID: UUID) {
        let key = Key(productID: ingredient.productID, unit: ingredient.unit)
        guard let current = values[key] else {
            order.append(key)
            values[key] = RecipeExpansion.Item(
                productID: ingredient.productID,
                productName: ingredient.productName,
                unit: ingredient.unit,
                quantity: quantity,
                recipeIDs: [recipeID]
            )
            return
        }
        // Like SQL `sum`: missing quantities are ignored unless every quantity is missing.
        let total: Double? =
            switch (current.quantity, quantity) {
            case (nil, nil): nil
            case let (lhs, rhs): (lhs ?? 0) + (rhs ?? 0)
            }
        values[key] = RecipeExpansion.Item(
            productID: current.productID,
            productName: current.productName,
            unit: current.unit,
            quantity: total,
            recipeIDs: current.recipeIDs.union([recipeID])
        )
    }

    var items: [RecipeExpansion.Item] {
        order.compactMap { values[$0] }.sorted { lhs, rhs in
            let byName = lhs.productName.localizedCaseInsensitiveCompare(rhs.productName)
            if byName != .orderedSame { return byName == .orderedAscending }
            return (lhs.unit ?? "") < (rhs.unit ?? "")
        }
    }
}
