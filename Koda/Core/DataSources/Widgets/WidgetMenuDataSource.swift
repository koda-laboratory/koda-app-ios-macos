import Foundation

/// Writes the widgets' menu snapshot (`WidgetMenu`) to the App Group container.
protocol WidgetMenuDataSource: Sendable {
    func write(_ menu: WidgetMenu) throws
    func remove()
}

final class FileWidgetMenuDataSource: WidgetMenuDataSource, Sendable {
    private let url: URL?

    init(url: URL? = WidgetMenu.fileURL) {
        self.url = url
    }

    func write(_ menu: WidgetMenu) throws {
        guard let url else { return }
        let data = try JSONEncoder().encode(menu)
        try data.write(to: url, options: [.atomic])
    }

    func remove() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
