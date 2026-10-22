import SwiftUI
import WidgetKit

// MARK: - Timeline

/// Placeholder "Hoy" widget. Phase 5 reads today's meals from the shared GRDB database in the App Group
/// (widgets never touch the network).
struct TodayEntry: TimelineEntry {
    let date: Date
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [TodayEntry(date: .now)], policy: .after(tomorrow)))
    }
}

// MARK: - View

struct TodayWidgetView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hoy")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(entry.date, format: .dateTime.weekday(.wide).day().month())
                .font(.caption)
                .opacity(0.8)
            Spacer(minLength: 0)
            Text("Abre Koda para ver el menú")
                .font(.caption2)
                .opacity(0.8)
        }
        .foregroundStyle(Color(red: 0.965, green: 0.933, blue: 0.922))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.051, green: 0.051, blue: 0.051),
                    Color(red: 0.349, green: 0.157, blue: 0.086),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Widget

struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Hoy")
        .description("Las comidas de hoy.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Hoy", as: .systemSmall) {
        TodayWidget()
    } timeline: {
        TodayEntry(date: .now)
    }
#endif
