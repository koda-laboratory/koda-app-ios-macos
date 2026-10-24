import SwiftUI

// MARK: - Colors

/// Koda palette (PLAN section 10). Three brand colors and colors derived from them; no others.
///
/// Brand constants are fixed. Semantic colors adapt to light and dark mode through the asset catalog
/// (`Resources/Assets.xcassets/Colors`), so views use the semantic ones.
enum KodaColor {
    // MARK: Brand

    /// `#0D0D0D`: main background in dark mode and primary text in light mode.
    static let onyx = Color(hex: 0x0D0D0D)
    /// `#592816`: brand color. Primary button, selected tab, highlighted surfaces and headers.
    static let walnut = Color(hex: 0x592816)
    /// `#CCA097`: accent. Chips, selection, checks, highlights and text on walnut.
    static let taupe = Color(hex: 0xCCA097)

    // MARK: Derived

    /// `#F6EEEB`: rosy cream, the light-mode background.
    static let cream = Color(hex: 0xF6EEEB)
    /// `#7A3A22`: lighter walnut for pressed and hover states.
    static let walnutLight = Color(hex: 0x7A3A22)
    /// `#2A140C`: very dark walnut, the elevated surface in dark mode.
    static let walnutDeep = Color(hex: 0x2A140C)
    /// Taupe at 20 %: chip fills and separators.
    static let taupeSoft = Color(hex: 0xCCA097, opacity: 0.2)
    /// `#E9D3CD`: light taupe, done band of the Today arcs and soft text on walnut.
    static let taupeLight = Color(hex: 0xE9D3CD)

    // MARK: Semantic (adaptive)

    static let background = Color("KodaBackground")
    static let surface = Color("KodaSurface")
    static let surfaceElevated = Color("KodaSurfaceElevated")
    static let textPrimary = Color("KodaTextPrimary")
    static let textSecondary = Color("KodaTextSecondary")
    /// Eyebrows and section labels ("COMIDA", "EN EL CONGELADOR"): `#7D5E55` / `#9C8680`, at least 4.5:1 on the
    /// background and cards.
    static let textTertiary = Color("KodaTextTertiary")
    /// Chip and icon-tile fills (`#F1E2DE` / walnut deep).
    static let chip = Color("KodaChip")
    /// Soft accent surface: suggestion card (`#E9D3CD` / walnut deep).
    static let accentSoft = Color("KodaAccentSoft")
    /// Segmented-control track (`#EADBD6` / walnut deep).
    static let control = Color("KodaControl")
    /// High-contrast secondary action: onyx in light, taupe in dark.
    static let inverse = Color("KodaInverse")
    static let onInverse = Color("KodaOnInverse")
    static let brand = Color("KodaBrand")
    static let onBrand = Color("KodaOnBrand")
    /// Brand-coloured text and glyphs on the background or cards: walnut in light, taupe in dark (contrast).
    static let brandText = Color("KodaBrandText")
    static let accent = Color("KodaAccent")
    static let separator = Color("KodaSeparator")
    /// `#B4533A`, desaturated so it does not break the palette; `#D0684D` in dark mode so error text keeps 4.5:1.
    static let error = Color("KodaError")
    /// `#6E8B5E`, desaturated so it does not break the palette.
    static let success = Color("KodaSuccess")
}

// MARK: - Gradient

enum KodaGradient {
    /// Signature gradient: onyx at the top to walnut at the bottom. Today hero and login.
    static let signature = LinearGradient(
        colors: [KodaColor.onyx, KodaColor.walnut],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Over a recipe photo: a light shade under the toolbar and a deep one under the title, so cream text stays
    /// readable on any image.
    static let photoScrim = LinearGradient(
        stops: [
            .init(color: KodaColor.onyx.opacity(0.35), location: 0),
            .init(color: KodaColor.onyx.opacity(0), location: 0.3),
            .init(color: KodaColor.onyx.opacity(0), location: 0.48),
            .init(color: KodaColor.onyx.opacity(0.82), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Previews

#if DEBUG
    #Preview("Palette") {
        let swatches: [(String, Color)] = [
            ("onyx", KodaColor.onyx), ("walnut", KodaColor.walnut), ("taupe", KodaColor.taupe),
            ("cream", KodaColor.cream), ("walnutLight", KodaColor.walnutLight),
            ("walnutDeep", KodaColor.walnutDeep), ("error", KodaColor.error), ("success", KodaColor.success),
        ]
        VStack(spacing: KodaSpacing.xs) {
            ForEach(swatches, id: \.0) { name, color in
                HStack {
                    RoundedRectangle(cornerRadius: KodaRadius.small).fill(color).frame(width: 44, height: 44)
                    Text(verbatim: name).font(KodaTypography.body)
                    Spacer()
                }
            }
        }
        .padding()
        .kodaPreview()
    }
#endif
