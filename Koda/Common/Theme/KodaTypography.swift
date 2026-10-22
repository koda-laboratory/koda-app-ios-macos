import SwiftUI

// MARK: - Typography

/// Type scale built on Dynamic Type text styles. Display titles use SF Pro Rounded.
enum KodaTypography {
    /// Large Title, 34 pt bold rounded: screen heroes ("Hoy", login).
    static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title2, design: .rounded, weight: .bold)
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.body
    static let callout = Font.callout
    static let caption = Font.caption
    static let emoji = Font.system(size: 56)
}

// MARK: - Previews

#if DEBUG
    #Preview("Typography") {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            Text(verbatim: "Hoy").font(KodaTypography.display)
            Text(verbatim: "Pollo al horno").font(KodaTypography.title)
            Text(verbatim: "Comida · 45 min").font(KodaTypography.headline)
            Text(verbatim: "Patatas, pollo, limón y romero.").font(KodaTypography.body)
            Text(verbatim: "8 productos").font(KodaTypography.callout)
            Text(verbatim: "Sin conexión · 3 cambios pendientes").font(KodaTypography.caption)
            Text(verbatim: "🍗").font(KodaTypography.emoji)
        }
        .foregroundStyle(KodaColor.textPrimary)
        .padding()
        .kodaPreview()
    }
#endif
