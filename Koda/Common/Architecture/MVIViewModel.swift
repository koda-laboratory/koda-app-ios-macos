// MARK: - MVI View Model

@MainActor
protocol MVIViewModel: AnyObject {
    associatedtype Intent: Sendable

    func send(_ intent: Intent) async
}
