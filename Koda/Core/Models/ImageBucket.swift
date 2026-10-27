/// The private Supabase Storage buckets of household images. Objects live at `<household>/<owner>/<uuid>.<ext>`,
/// where the owner is the recipe or the product the image belongs to.
enum ImageBucket: String, CaseIterable, Sendable, Hashable {
    case recipes = "recipe-images"
    case products = "product-images"
}
