import Foundation

/// Deterministic sample values for design-system component previews.
enum PresentationPreviewFactory {
    static let recipeNames = [
        "Arroz a la cubana", "Curry Japonés", "Ramen", "Paella de carrilleras", "Burrito", "Gazpacho",
    ]

    /// A stable UUID derived from a name.
    static func id(for name: String) -> UUID {
        let value = name.unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1.value) }
        return UUID(uuidString: String(format: "00000000-0000-4000-8000-%012llx", value & 0xFFFF_FFFF_FFFF)) ?? UUID()
    }

    static let week: [LocalDay] = (0..<7).map { LocalDay(year: 2026, month: 10, day: 19).adding(days: $0) }
    static let today = LocalDay(year: 2026, month: 10, day: 22)
}
