import SwiftUI

// MARK: - Flow Layout

/// Lays its subviews out in rows, wrapping to the next row when one does not fit ("Tiendas" chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = KodaSpacing.xs
    var lineSpacing: CGFloat = KodaSpacing.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var originY = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var originX = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: originX, y: originY), proposal: ProposedViewSize(size))
                originX += size.width + spacing
            }
            originY += row.height + lineSpacing
        }
    }

    // MARK: - Private Methods

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Flow layout") {
        FlowLayout {
            ForEach(["Ahorramas", "Alcampo", "Aldi", "Mercadito", "Mercadona"], id: \.self) { name in
                TagView(text: name)
            }
        }
        .frame(width: 300)
        .padding()
        .kodaPreview()
    }

    #Preview("Flow layout · dark") {
        FlowLayout {
            ForEach(["Ahorramas", "Alcampo", "Aldi"], id: \.self) { name in
                TagView(text: name)
            }
        }
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Flow layout · Mac", traits: .fixedLayout(width: 600, height: 200)) {
        FlowLayout {
            ForEach(["Ahorramas", "Alcampo", "Aldi", "Mercadito", "Mercadona"], id: \.self) { name in
                TagView(text: name)
            }
        }
        .padding()
        .kodaPreview()
    }
#endif
