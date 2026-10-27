import SwiftUI

/// How a recipe link reads and looks: the platform tile, the title ("Reel de Instagram") and the subtitle
/// ("@cocinaconana · se abre en TikTok").
struct RecipeLinkPresentation {
    let info: RecipeLinkInfo

    var title: String {
        switch info.platform {
        case .tiktok: String(localized: "recipe.links.title.tiktok")
        case .instagram: String(localized: "recipe.links.title.instagram")
        case .youtube: String(localized: "recipe.links.title.youtube")
        case .other: info.source
        }
    }

    var subtitle: String {
        let who = info.account ?? info.source
        guard let app = appName else { return who }
        return String(localized: "recipe.links.opens-in \(who) \(app)")
    }

    /// SF Symbols has no brand logos: a glyph that evokes each platform.
    var systemImage: String {
        switch info.platform {
        case .tiktok: "music.note"
        case .instagram: "camera"
        case .youtube: "play.fill"
        case .other: "link"
        }
    }

    var tileFill: Color {
        switch info.platform {
        case .tiktok: KodaColor.onyx
        case .instagram: KodaColor.walnut
        case .youtube: KodaColor.taupe
        case .other: KodaColor.chip
        }
    }

    var glyphColor: Color {
        switch info.platform {
        case .tiktok, .instagram: KodaColor.cream
        case .youtube: KodaColor.walnut
        case .other: KodaColor.brandText
        }
    }

    private var appName: String? {
        switch info.platform {
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .youtube: "YouTube"
        case .other: nil
        }
    }
}

/// The rounded platform tile of a link.
struct RecipeLinkTile: View {
    let presentation: RecipeLinkPresentation

    var body: some View {
        Image(systemName: presentation.systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(presentation.glyphColor)
            .frame(width: KodaSize.linkTile, height: KodaSize.linkTile)
            .background(
                presentation.tileFill,
                in: RoundedRectangle(cornerRadius: KodaRadius.small, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}
