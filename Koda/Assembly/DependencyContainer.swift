@preconcurrency import Swinject

/// Owns the immutable dependency graph and exposes only Swinject's synchronized resolver.
///
/// Swinject predates strict concurrency and does not annotate `Resolver` as `Sendable`.
/// Registrations finish before `resolver` is published and every subsequent resolution goes
/// through the synchronized container protected by Swinject's lock.
final class DependencyContainer: Sendable {
    static let shared = DependencyContainer()

    // `SynchronizedResolver` is protected by Swinject's recursive lock, but its public protocol
    // does not express that guarantee to Swift's concurrency checker.
    private nonisolated(unsafe) let resolver: Resolver

    private init() {
        self.resolver = Self.makeResolver(assemblies: Self.productionAssemblies)
    }

    init(previewAssemblies: [any Swinject.Assembly]) {
        self.resolver = Self.makeResolver(
            assemblies: Self.productionAssemblies + previewAssemblies
        )
    }

    private static var productionAssemblies: [any Swinject.Assembly] {
        [
            Assembly.Core(), Assembly.Auth(), Assembly.Products(), Assembly.Recipes(), Assembly.Planning(),
            Assembly.Shopping(),
        ]
    }

    private static func makeResolver(assemblies: [any Swinject.Assembly]) -> Resolver {
        let container = Container()
        let assembler = Assembler(assemblies, container: container)

        guard let assembledContainer = assembler.resolver as? Container else {
            fatalError("Swinject assembler did not expose its backing container.")
        }

        return assembledContainer.synchronize()
    }

    func resolve<Service>(_ serviceType: Service.Type = Service.self, name: String? = nil) -> Service? {
        resolver.resolve(serviceType, name: name)
    }

    func required<Service>(_ serviceType: Service.Type = Service.self, name: String? = nil) -> Service {
        guard let service = resolve(serviceType, name: name) else {
            fatalError(
                "Missing Swinject registration for \(String(reflecting: serviceType))"
                    + (name.map { " named '\($0)'" } ?? "")
                    + "."
            )
        }
        return service
    }
}
