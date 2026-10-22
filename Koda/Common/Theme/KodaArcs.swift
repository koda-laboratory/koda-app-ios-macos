import SwiftUI

// MARK: - Arc Shape

/// One "U": two vertical arms joined by a half circle at the bottom, inset from the bounding rect.
/// The path starts at the top of the left arm, so trimming it fills the "U" from left to right.
struct KodaUArc: Shape {
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = max(rect.width / 2 - inset, 0)
        let left = rect.minX + inset
        let right = rect.maxX - inset
        let centerY = max(rect.maxY - inset - radius, rect.minY)
        var path = Path()
        path.move(to: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: left, y: centerY))
        path.addRelativeArc(
            center: CGPoint(x: rect.midX, y: centerY),
            radius: radius,
            startAngle: .degrees(180),
            delta: .degrees(-180)
        )
        path.addLine(to: CGPoint(x: right, y: rect.minY))
        return path
    }
}

// MARK: - Arcs

/// Signature motif: concentric "U" arcs in onyx, walnut and taupe.
///
/// Each arc can be partially filled (`progress` 0…1). In the Today hero every arc is a meal of the day and
/// fills when it is marked as eaten; login and empty states show them fully filled.
struct KodaArcs: View {
    struct Arc: Identifiable, Sendable {
        let id: Int
        let color: Color
        let progress: Double
    }

    let arcs: [Arc]
    var lineWidth: CGFloat
    var gap: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - progress: fill of each arc from the outermost inwards. Defaults to three filled arcs.
    ///   - colors: arc colors from the outermost inwards; cycles when there are more arcs than colors.
    init(
        progress: [Double] = [1, 1, 1],
        colors: [Color] = [KodaColor.onyx, KodaColor.walnut, KodaColor.taupe],
        lineWidth: CGFloat = 18,
        gap: CGFloat = 10
    ) {
        let palette = colors.isEmpty ? [KodaColor.walnut] : colors
        self.arcs = progress.enumerated().map { index, value in
            Arc(id: index, color: palette[index % palette.count], progress: min(max(value, 0), 1))
        }
        self.lineWidth = lineWidth
        self.gap = gap
    }

    var body: some View {
        ZStack {
            ForEach(arcs) { arc in
                let shape = KodaUArc(inset: lineWidth / 2 + CGFloat(arc.id) * (lineWidth + gap))
                shape
                    .stroke(arc.color.opacity(0.18), style: strokeStyle)
                shape
                    .trim(from: 0, to: arc.progress)
                    .stroke(arc.color, style: strokeStyle)
                    .animation(reduceMotion ? nil : .spring(duration: 0.6), value: arc.progress)
            }
        }
        .aspectRatio(0.8, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Arcs · filled") {
        KodaArcs()
            .frame(width: 220)
            .padding()
            .kodaPreview()
    }

    #Preview("Arcs · meals of the day") {
        @Previewable @State var progress: [Double] = [1, 0.5, 0]
        VStack(spacing: KodaSpacing.l) {
            KodaArcs(progress: progress, colors: [KodaColor.taupe, KodaColor.cream, KodaColor.walnutLight])
                .frame(width: 200)
            Button("Comer") {
                progress = progress.map { min($0 + 0.5, 1) }
            }
            .buttonStyle(.glassProminent)
        }
        .padding(KodaSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KodaGradient.signature)
    }

    #Preview("Arcs · Mac", traits: .fixedLayout(width: 900, height: 600)) {
        KodaArcs(progress: [1, 1, 1, 1], lineWidth: 24)
            .frame(width: 320)
            .kodaPreview()
    }
#endif
