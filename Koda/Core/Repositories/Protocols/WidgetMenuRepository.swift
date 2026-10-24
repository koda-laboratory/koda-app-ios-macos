import Foundation

/// Publishes the menu the widgets show and asks WidgetKit to refresh them.
protocol WidgetMenuRepository: Sendable {
    func publish(_ menu: WidgetMenu)
    /// Signing out removes the household's menu from the widgets.
    func clear()
}
