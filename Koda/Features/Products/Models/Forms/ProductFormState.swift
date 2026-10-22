import Foundation

/// Product editor: name, emoji, category, stores, prices and default unit.
struct ProductFormState: FormState {
    var name = ""
    var emoji = ""
    var category = ProductCategory.food
    var storeIDs: Set<UUID> = []
    var pricePerKgText = ""
    var priceTotalText = ""
    var defaultUnit = ""
    var notes: String?

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var pricePerKg: Double? { Self.price(pricePerKgText) }
    var priceTotal: Double? { Self.price(priceTotalText) }
    var arePricesValid: Bool {
        (pricePerKgText.isEmpty || (pricePerKg ?? -1) >= 0) && (priceTotalText.isEmpty || (priceTotal ?? -1) >= 0)
    }

    var isValid: Bool { !trimmedName.isEmpty && arePricesValid }

    static func price(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    func input(id: UUID?) -> ProductInput {
        let unit = defaultUnit.trimmingCharacters(in: .whitespaces)
        return ProductInput(
            id: id,
            name: trimmedName,
            category: category,
            defaultUnit: unit.isEmpty ? nil : unit,
            pricePerKg: pricePerKg,
            priceTotal: priceTotal,
            notes: notes,
            emoji: emoji.isEmpty ? nil : emoji,
            storeIDs: storeIDs
        )
    }
}
