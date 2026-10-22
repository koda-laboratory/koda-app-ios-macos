import Foundation
import Network

/// Network reachability, as a stream of "is online" values.
protocol NetworkReachabilityMonitoring: Sendable {
    /// Emits the current state first and then every change.
    func updates() -> AsyncStream<Bool>
}

/// `NWPathMonitor`-backed reachability (iPhone and Mac).
final class NetworkPathReachability: NetworkReachabilityMonitoring, Sendable {
    func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "com.kodalabs.app.reachability"))
        }
    }
}
