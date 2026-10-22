import SwiftUI

/// The login hero: the three hanging arcs with the meals of the day written inside their bands.
struct LoginArcsHeader: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let band = width / 2 / 3.15
            ZStack(alignment: .top) {
                KodaArcs(aspectRatio: 470.0 / 330.0)
                label("login.arcs.breakfast", color: KodaColor.taupe, centerX: width / 2, centerY: height - band * 0.55)
                label("login.arcs.lunch", color: KodaColor.cream, centerX: width / 2, centerY: height - band * 1.55)
                label("login.arcs.dinner", color: KodaColor.walnut, centerX: width / 2, centerY: height - band * 2.75)
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(330.0 / 470.0, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func label(_ key: LocalizedStringKey, color: Color, centerX: CGFloat, centerY: CGFloat) -> some View {
        Text(key)
            .font(.system(.caption, design: .rounded, weight: .heavy))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .position(x: centerX, y: centerY)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Login arcs") {
        LoginArcsHeader()
            .frame(width: 330)
            .kodaPreview()
    }

    #Preview("Login arcs · dark") {
        LoginArcsHeader()
            .frame(width: 330)
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Login arcs · Mac", traits: .fixedLayout(width: 900, height: 600)) {
        LoginArcsHeader()
            .frame(width: 280)
            .kodaPreview()
    }
#endif
