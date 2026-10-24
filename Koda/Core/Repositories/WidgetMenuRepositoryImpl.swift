import Foundation

final class WidgetMenuRepositoryImpl: WidgetMenuRepository, Sendable {
    private let dataSource: any WidgetMenuDataSource
    private let reloader: any WidgetTimelineReloading
    private let loggerService: any LoggerService

    init(
        dataSource: any WidgetMenuDataSource,
        reloader: any WidgetTimelineReloading,
        loggerService: any LoggerService
    ) {
        self.dataSource = dataSource
        self.reloader = reloader
        self.loggerService = loggerService
    }

    func publish(_ menu: WidgetMenu) {
        do {
            try dataSource.write(menu)
        } catch {
            loggerService.warning("The widget menu could not be written.")
            return
        }
        reloader.reloadAllTimelines()
    }

    func clear() {
        dataSource.remove()
        reloader.reloadAllTimelines()
    }
}
