import SwiftUI

// MARK: - U Shape

/// One filled "U" hanging from the top edge: two vertical arms joined by a half circle at the bottom.
///
/// Every nested U shares the same arc centre (`maxY - width / 2`), so inner shapes end higher and the bands keep
/// the same thickness all around, like the reference artwork.
struct KodaUShape: Shape {
    /// Horizontal inset of this U inside the outer bounds.
    var inset: CGFloat
    /// `false` draws only the outline of the arms and the bottom (no top edge), for the dashed pending band.
    var closesTop = true

    func path(in rect: CGRect) -> Path {
        let outerRadius = rect.width / 2
        let radius = max(outerRadius - inset, 0)
        let centerY = rect.maxY - outerRadius
        let left = rect.minX + inset
        let right = rect.maxX - inset
        var path = Path()
        path.move(to: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: left, y: centerY))
        path.addArc(
            center: CGPoint(x: rect.midX, y: centerY),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: right, y: rect.minY))
        if closesTop {
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Arcs

/// Signature motif: three nested "U" shapes hanging from the top — onyx outside, dark walnut in the middle and
/// rosy taupe inside. Decorative (login, empty states, detail headers).
struct KodaArcs: View {
    var colors: [Color] = [KodaColor.onyx, KodaColor.walnut, KodaColor.taupe]
    /// Height / width of the outer U. The reference artwork is slightly taller than wide.
    var aspectRatio: CGFloat = 132.0 / 112.0

    var body: some View {
        GeometryReader { proxy in
            let band = proxy.size.width / 2 / (CGFloat(colors.count) + 0.15)
            ZStack {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    KodaUShape(inset: CGFloat(index) * band)
                        .fill(color)
                }
            }
        }
        .aspectRatio(1 / aspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: - Progress Arcs

/// The Today hero: one band per meal (breakfast outside, lunch, dinner inside). A done band is filled; a pending
/// one keeps the hero background with a dashed outline.
struct KodaProgressArcs: View {
    let bandsDone: [Bool]
    let doneCount: Int
    let totalCount: Int
    /// Colours of the done bands, outermost first.
    var doneColors: [Color] = [KodaColor.taupe, KodaColor.taupeLight, KodaColor.cream]
    var pendingColor: Color = KodaColor.walnutDeep
    var outlineColor: Color = KodaColor.taupe

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let band = proxy.size.width / 2 / (CGFloat(bandsDone.count) + 0.15)
            ZStack {
                ForEach(Array(bandsDone.enumerated()), id: \.offset) { index, isDone in
                    let inset = CGFloat(index) * band
                    KodaUShape(inset: inset)
                        .fill(isDone ? doneColors[index % doneColors.count] : pendingColor)
                    if !isDone {
                        KodaUShape(inset: inset + 1, closesTop: false)
                            .stroke(outlineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5]))
                    }
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.6), value: bandsDone)
        }
        .aspectRatio(112.0 / 132.0, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("today.progress.accessibility-label"))
        .accessibilityValue(Text("today.progress.accessibility-value \(doneCount) \(totalCount)"))
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Arcs · iPhone") {
        KodaArcs()
            .frame(width: 220)
            .padding()
            .kodaPreview()
    }

    #Preview("Arcs · progress") {
        HStack(spacing: KodaSpacing.l) {
            KodaProgressArcs(bandsDone: [true, true, false], doneCount: 2, totalCount: 3)
            KodaProgressArcs(bandsDone: [true, false, false], doneCount: 1, totalCount: 3)
            KodaProgressArcs(bandsDone: [true, true, true], doneCount: 3, totalCount: 3)
        }
        .frame(height: 132)
        .padding(KodaSpacing.l)
        .background(KodaGradient.signature)
        .kodaPreview()
    }

    #Preview("Arcs · dark", traits: .fixedLayout(width: 400, height: 400)) {
        KodaArcs()
            .frame(width: 200)
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Arcs · Mac", traits: .fixedLayout(width: 900, height: 600)) {
        KodaArcs(aspectRatio: 470.0 / 330.0)
            .frame(width: 330)
            .kodaPreview()
    }
#endif
