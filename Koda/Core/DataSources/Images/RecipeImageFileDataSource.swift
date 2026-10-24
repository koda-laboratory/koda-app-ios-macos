import Foundation

/// Recipe images on disk, by Storage path, in the App Group container (`RecipeImages/<household>/<recipe>/…`): the
/// photos taken on this device until they are uploaded, and every downloaded image afterwards (a cache that is
/// only cleared on sign-out).
protocol RecipeImageFileDataSource: Sendable {
    func data(at path: String) -> Data?
    func fileURL(at path: String) -> URL?
    func write(_ data: Data, at path: String) throws(KodaError)
    func remove(at path: String)
    func removeAll()
}

final class AppGroupRecipeImageFileDataSource: RecipeImageFileDataSource, Sendable {
    private let root: URL?

    init(root: URL? = AppGroupRecipeImageFileDataSource.defaultRoot()) {
        self.root = root
    }

    func data(at path: String) -> Data? {
        guard let url = url(for: path) else { return nil }
        return try? Data(contentsOf: url)
    }

    func fileURL(at path: String) -> URL? {
        guard let url = url(for: path), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func write(_ data: Data, at path: String) throws(KodaError) {
        guard let url = url(for: path) else {
            throw KodaError(type: .storage, reason: "Invalid image path.")
        }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            throw KodaError(type: .storage, reason: "Could not store the image: \(error.localizedDescription)")
        }
    }

    func remove(at path: String) {
        guard let url = url(for: path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func removeAll() {
        guard let root else { return }
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Private Methods

    /// Only `a/b/c.ext` style paths below the root (no `..`, no absolute paths).
    private func url(for path: String) -> URL? {
        let components = path.split(separator: "/").map(String.init)
        guard let root, !components.isEmpty, !components.contains(where: { $0 == ".." || $0 == "." }) else {
            return nil
        }
        return components.reduce(root) { $0.appending(path: $1) }
    }

    private static func defaultRoot() -> URL? {
        let fileManager = FileManager.default
        let base =
            fileManager.containerURL(forSecurityApplicationGroupIdentifier: WidgetMenu.appGroup)
            ?? (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ))?
            .appending(path: "Koda")
        return base?.appending(path: "RecipeImages", directoryHint: .isDirectory)
    }
}
