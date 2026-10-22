extension AsyncStream where Element: Sendable {
    /// Transforms every element, keeping an `AsyncStream` (domain observation APIs return `AsyncStream`).
    /// Cancelling the consumer cancels the upstream iteration.
    func mapStream<Output: Sendable>(_ transform: @escaping @Sendable (Element) -> Output) -> AsyncStream<Output> {
        AsyncStream<Output> { continuation in
            let task = Task {
                for await value in self {
                    continuation.yield(transform(value))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
