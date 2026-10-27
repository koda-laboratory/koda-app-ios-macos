import Foundation

/// Household images on disk, by bucket and Storage path, in the App Group container: recipe images under
/// `RecipeImages/<household>/<recipe>/…` and product images under `ProductImages/<household>/<product>/…`. They are the
/// photos taken on this device until they are uploaded, and every downloaded image afterwards (a cache that is only
/// cleared on sign-out).
protocol RecipeImageFileDataSource: Sendable {
    func data(at path: String, bucket: ImageBucket) -> Data?
    func fileURL(at path: String, bucket: ImageBucket) -> URL?
    func write(_ data: Data, at path: String, bucket: ImageBucket) throws(KodaError)
    func remove(at path: String, bucket: ImageBucket)
    /// Every bucket.
    func removeAll()
}

final class AppGroupRecipeImageFileDataSource: RecipeImageFileDataSource, Sendable {
    private let base: URL?

    /// `base` holds one folder per bucket (`RecipeImages` keeps the name earlier versions used, so their cache stays).
    init(base: URL? = AppGroupRecipeImageFileDataSource.defaultBase()) {
        self.base = base
    }

    func data(at path: String, bucket: ImageBucket) -> Data? {
        guard let url = url(for: path, bucket: bucket) else { return nil }
        return try? Data(contentsOf: url)
    }

    func fileURL(at path: String, bucket: ImageBucket) -> URL? {
        guard let url = url(for: path, bucket: bucket), FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    func write(_ data: Data, at path: String, bucket: ImageBucket) throws(KodaError) {
        guard let url = url(for: path, bucket: bucket) else {
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

    func remove(at path: String, bucket: ImageBucket) {
        guard let url = url(for: path, bucket: bucket) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func removeAll() {
        for bucket in ImageBucket.allCases {
            guard let root = root(for: bucket) else { continue }
            try? FileManager.default.removeItem(at: root)
        }
    }

    // MARK: - Private Methods

    private func root(for bucket: ImageBucket) -> URL? {
        let folder =
            switch bucket {
            case .recipes: "RecipeImages"
            case .products: "ProductImages"
            }
        return base?.appending(path: folder, directoryHint: .isDirectory)
    }

    /// Only `a/b/c.ext` style paths below the bucket's root (no `..`, no absolute paths).
    private func url(for path: String, bucket: ImageBucket) -> URL? {
        let components = path.split(separator: "/").map(String.init)
        guard let root = root(for: bucket), !components.isEmpty,
            !components.contains(where: { $0 == ".." || $0 == "." })
        else {
            return nil
        }
        return components.reduce(root) { $0.appending(path: $1) }
    }

    private static func defaultBase() -> URL? {
        let fileManager = FileManager.default
        return fileManager.containerURL(forSecurityApplicationGroupIdentifier: WidgetMenu.appGroup)
            ?? (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ))?
            .appending(path: "Koda")
    }
}
