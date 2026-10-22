/// `public.product_category`, in the order the shopping list groups them.
enum ProductCategory: String, CaseIterable, Sendable, Codable {
    case food
    case basics
    case cleaning
    case kitchen
    case bathroom
    case toiletries
}
