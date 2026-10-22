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
    /// Content cards (meal cards, lists): between medium and large, as in the approved mockups.
    static let card: CGFloat = 22
    /// Icon tiles inside cards.
    static let tile: CGFloat = 18
    /// Large enough to round any control into a capsule; prefer `Capsule()` for shapes.
    static let pill: CGFloat = 999
}

// MARK: - Sizes

/// Fixed component sizes of the design system.
enum KodaSize {
    /// Minimum hit target.
    static let hitTarget: CGFloat = 44
    static let chipHeight: CGFloat = 36
    static let weekDayHeight: CGFloat = 70
    static let dot: CGFloat = 5
    static let avatar: CGFloat = 44
    /// Meal card icon tile.
    static let mealTile: CGFloat = 60
    /// The floating "+" button.
    static let fab: CGFloat = 58
    /// Shopping status dot.
    static let statusDot: CGFloat = 26
    /// Today hero arcs.
    static let heroArcsWidth: CGFloat = 112
    /// Recipe tile colour block.
    static let recipeTileHeight: CGFloat = 130
    /// "Hace tiempo que no" carousel card.
    static let carouselCardWidth: CGFloat = 230
    static let carouselCardHeight: CGFloat = 150
    static let fieldHeight: CGFloat = 52
    static let gridCellHeight: CGFloat = 96
    /// Slot label column of the planning rows and the Mac week grid.
    static let slotLabelWidth: CGFloat = 76
    static let formWidth: CGFloat = 480
    static let loginArcsWidth: CGFloat = 420
    /// Readable column on the Mac.
    static let readableWidth: CGFloat = 760
}
