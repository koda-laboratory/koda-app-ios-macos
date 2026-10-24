import SwiftUI
import WidgetKit

// MARK: - Timeline

/// The menu for the widget: today's meals (and tomorrow's for the medium size), read from the snapshot the app
/// keeps in the App Group (`WidgetMenu`). The widget never opens the database or the network.
struct TodayEntry: TimelineEntry {
    let date: Date
    /// `nil` before the app has written a menu (not signed in yet).
    let menu: WidgetMenu?

    var today: [WidgetMenu.Meal]? { menu?.meals(on: date) }
    var tomorrow: [WidgetMenu.Meal]? { menu?.meals(on: date.addingTimeInterval(86_400)) }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, menu: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, menu: context.isPreview ? .sample : WidgetMenu.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date.now
        let menu = WidgetMenu.load()
        // One entry now and one at the start of each following day, so the widget moves to the next day at
        // midnight even when the app is not opened. The app reloads the timeline whenever the plan changes.
        let dayStarts = menu?.dayStarts(after: now) ?? []
        let entries = [TodayEntry(date: now, menu: menu)] + dayStarts.map { TodayEntry(date: $0, menu: menu) }
        let refresh = dayStarts.last ?? Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

// MARK: - Views

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.menu == nil {
                SignedOutView()
            } else if family == .systemMedium {
                HStack(alignment: .top, spacing: 14) {
                    DayColumn(titleKey: "widget.today", date: entry.date, meals: entry.today ?? [], now: entry.date)
                    Rectangle()
                        .fill(WidgetPalette.taupe.opacity(0.25))
                        .frame(width: 1)
                    DayColumn(
                        titleKey: "widget.tomorrow",
                        date: entry.date.addingTimeInterval(86_400),
                        meals: entry.tomorrow ?? [],
                        now: nil
                    )
                }
            } else {
                DayColumn(titleKey: "widget.today", date: entry.date, meals: entry.today ?? [], now: entry.date)
            }
        }
        .kodaWidgetStyle()
        .widgetURL(URL(string: "koda://today"))
    }
}

/// "HOY · sáb 24" and the day's meals: slot, name and time.
private struct DayColumn: View {
    let titleKey: LocalizedStringKey
    let date: Date
    let meals: [WidgetMenu.Meal]
    /// For today: meals already past are dimmed.
    let now: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(titleKey)
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(WidgetPalette.taupe)
                Text(date, format: .dateTime.weekday(.abbreviated).day())
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(WidgetPalette.cream.opacity(0.6))
            }
            if meals.isEmpty {
                Spacer(minLength: 0)
                Text("widget.nothing")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(WidgetPalette.cream.opacity(0.75))
                Spacer(minLength: 0)
            } else {
                ForEach(Array(meals.prefix(3).enumerated()), id: \.offset) { _, meal in
                    MealLine(meal: meal, isPast: isPast(meal))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isPast(_ meal: WidgetMenu.Meal) -> Bool {
        guard let now else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0) > meal.minutes + 90
    }
}

private struct MealLine: View {
    let meal: WidgetMenu.Meal
    let isPast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: "\(meal.slotTitle.uppercased()) · \(meal.timeText)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetPalette.taupe)
            Text(verbatim: meal.title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .opacity(isPast ? 0.5 : 1)
    }
}

private struct SignedOutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("widget.today")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(WidgetPalette.taupe)
            Spacer(minLength: 0)
            Text("widget.signed-out")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
    }
}

// MARK: - Widget

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetMenu.widgetKind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("widget.name"))
        .description(Text("widget.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Sample

extension WidgetMenu {
    /// Gallery and placeholder content.
    static var sample: WidgetMenu {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        func day(offset: Int, _ meals: [WidgetMenu.Meal]) -> WidgetMenu.Day {
            let date = Date.now.addingTimeInterval(TimeInterval(offset) * 86_400)
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return WidgetMenu.Day(
                year: components.year ?? 0,
                month: components.month ?? 0,
                day: components.day ?? 0,
                meals: meals
            )
        }
        func meal(_ slot: String, _ title: String, hour: Int, isRecipe: Bool = true) -> WidgetMenu.Meal {
            WidgetMenu.Meal(slotTitle: slot, title: title, minutes: hour * 60 + 30, isRecipe: isRecipe)
        }
        return WidgetMenu(
            timeZoneIdentifier: TimeZone.current.identifier,
            days: [
                day(offset: 0, [meal("Comida", "Lentejas", hour: 14), meal("Cena", "Tortilla de patata", hour: 21)]),
                day(offset: 1, [meal("Comida", "Comemos fuera", hour: 14, isRecipe: false)]),
            ]
        )
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Hoy · small", as: .systemSmall) {
        TodayWidget()
    } timeline: {
        TodayEntry(date: .now, menu: .sample)
        TodayEntry(date: .now, menu: .empty)
        TodayEntry(date: .now, menu: nil)
    }

    #Preview("Hoy y mañana · medium", as: .systemMedium) {
        TodayWidget()
    } timeline: {
        TodayEntry(date: .now, menu: .sample)
    }
#endif
