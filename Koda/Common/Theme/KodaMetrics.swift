import CoreGraphics

// MARK: - Spacing

// Short t-shirt sizes are the intended token names (KodaSpacing.m), mirrored by the design system skill.
// swiftlint:disable identifier_name

/// Spacing scale: 4 / 8 / 12 / 16 / 24 / 32.
enum KodaSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
}

// swiftlint:enable identifier_name

// MARK: - Radius

/// Corner radii: 12 / 20 / 28 and a pill.
enum KodaRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 20
    static let large: CGFloat = 28
    /// Large enough to round any control into a capsule; prefer `Capsule()` for shapes.
    static let pill: CGFloat = 999
}
