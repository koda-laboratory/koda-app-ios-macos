import WidgetKit

/// Reloads widget timelines after a pull changed local data.
protocol WidgetTimelineReloading: Sendable {
    func reloadAllTimelines()
}

struct WidgetCenterTimelineReloader: WidgetTimelineReloading {
    func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
