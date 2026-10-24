import SwiftUI
import WidgetKit

// MARK: - Timeline

/// What is left to buy, read from the snapshot the app keeps in the App Group (`WidgetMenu.shopping`). Tapping it
/// opens the list in Koda; products are ticked in the app or from the Siri card.
struct ShoppingEntry: TimelineEntry {
    let date: Date
    /// `nil` before the app has written a snapshot (not signed in yet).
    let shopping: WidgetMenu.Shopping?
}

struct ShoppingProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShoppingEntry {
        ShoppingEntry(date: .now, shopping: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShoppingEntry) -> Void) {
        completion(ShoppingEntry(date: .now, shopping: context.isPreview ? .sample : WidgetMenu.load()?.shopping))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoppingEntry>) -> Void) {
        // The app reloads this timeline whenever the list changes; nothing changes on its own.
        let entry = ShoppingEntry(date: .now, shopping: WidgetMenu.load()?.shopping)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Views

struct ShoppingWidgetView: View {
    let entry: ShoppingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("widget.shopping.title")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(WidgetPalette.taupe)
                Spacer(minLength: 0)
                if let count = entry.shopping?.pendingCount, count > 0 {
                    Text(verbatim: "\(count)")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                }
            }
            if let shopping = entry.shopping {
                if shopping.items.isEmpty {
                    Spacer(minLength: 0)
                    Text("widget.shopping.done")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(WidgetPalette.cream.opacity(0.75))
                    Spacer(minLength: 0)
                } else {
                    ItemsGrid(items: shopping.items, columns: family == .systemMedium ? 2 : 1, rows: 4)
                    Spacer(minLength: 0)
                }
            } else {
                Spacer(minLength: 0)
                Text("widget.signed-out")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
        }
        .kodaWidgetStyle()
        .widgetURL(URL(string: "koda://shopping"))
    }
}

/// Up to `columns × rows` products with an empty circle, like the list.
private struct ItemsGrid: View {
    let items: [String]
    let columns: Int
    let rows: Int

    var body: some View {
        let visible = Array(items.prefix(columns * rows))
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<columns, id: \.self) { column in
                let names = visible.enumerated().filter { $0.offset / rows == column }.map(\.element)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(names, id: \.self) { name in
                        HStack(spacing: 6) {
                            Circle()
                                .strokeBorder(WidgetPalette.taupe, lineWidth: 1.5)
                                .frame(width: 11, height: 11)
                            Text(verbatim: name)
                                .font(.system(.footnote, design: .rounded, weight: .semibold))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Widget

struct ShoppingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetMenu.shoppingWidgetKind, provider: ShoppingProvider()) { entry in
            ShoppingWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("widget.shopping.name"))
        .description(Text("widget.shopping.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension WidgetMenu.Shopping {
    /// Gallery and placeholder content.
    static let sample = WidgetMenu.Shopping(
        pendingCount: 6,
        items: ["Leche", "Huevos", "Patatas", "Cebolla", "Aceite de oliva", "Tomate triturado"]
    )
}

// MARK: - Previews

#if DEBUG
    #Preview("Compra · small", as: .systemSmall) {
        ShoppingWidget()
    } timeline: {
        ShoppingEntry(date: .now, shopping: .sample)
        ShoppingEntry(date: .now, shopping: WidgetMenu.Shopping(pendingCount: 0, items: []))
        ShoppingEntry(date: .now, shopping: nil)
    }

    #Preview("Compra · medium", as: .systemMedium) {
        ShoppingWidget()
    } timeline: {
        ShoppingEntry(date: .now, shopping: .sample)
    }
#endif
