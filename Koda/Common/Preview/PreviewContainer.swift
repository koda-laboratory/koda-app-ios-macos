import Foundation
import Swinject

/// Dependency graph for previews: the production assemblies with the database replaced by a seeded in-memory
/// one. Nothing here talks to the network unless a preview explicitly triggers a remote action.
enum PreviewContainer {
    static let populated = DependencyContainer(previewAssemblies: [PreviewDatabaseAssembly(content: .populated)])
    static let empty = DependencyContainer(previewAssemblies: [PreviewDatabaseAssembly(content: .empty)])
}

private final class PreviewDatabaseAssembly: Swinject.Assembly {
    private let content: PreviewDatabase.Content

    init(content: PreviewDatabase.Content) {
        self.content = content
    }

    func assemble(container: Container) {
        let content = content
        container.register(AppDatabase.self) { _ in PreviewDatabase.make(content) }
            .inObjectScope(.container)
    }
}
