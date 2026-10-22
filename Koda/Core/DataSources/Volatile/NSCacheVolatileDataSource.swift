import Foundation

protocol VolatileDataSource: StorableDataSource {}

actor NSCacheVolatileDataSource: VolatileDataSource {
    private final class CacheItem: NSObject {
        let data: Data

        init(data: Data) {
            self.data = data
        }
    }

    // MARK: - Properties

    private let cache = NSCache<NSString, CacheItem>()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var identifiersByType: [String: Set<String>] = [:]

    // MARK: - Lifecycle

    init() {}

    // MARK: - CRUD

    func create(_ object: some Storable) throws {
        try store(object)
    }

    func read<Value: Storable>(_ type: Value.Type, id: String) throws -> Value? {
        let key = cacheKey(for: type, id: id)
        guard let item = cache.object(forKey: key as NSString) else {
            identifiersByType[type.storageIdentifier]?.remove(id)
            return nil
        }

        do {
            return try decoder.decode(type, from: item.data)
        } catch {
            cache.removeObject(forKey: key as NSString)
            identifiersByType[type.storageIdentifier]?.remove(id)
            throw error
        }
    }

    func readAll<Value: Storable>(_ type: Value.Type) throws -> [Value] {
        try (identifiersByType[type.storageIdentifier] ?? []).compactMap { id in
            try read(type, id: id)
        }
    }

    func update(_ object: some Storable) throws {
        try store(object)
    }

    func delete(_ type: (some Storable).Type, id: String) {
        cache.removeObject(forKey: cacheKey(for: type, id: id) as NSString)
        identifiersByType[type.storageIdentifier]?.remove(id)
    }

    func deleteAll(_ type: (some Storable).Type) {
        let storageIdentifier = type.storageIdentifier
        for id in identifiersByType[storageIdentifier] ?? [] {
            cache.removeObject(forKey: cacheKey(for: type, id: id) as NSString)
        }
        identifiersByType[storageIdentifier] = nil
    }

    func deleteStorage() {
        cache.removeAllObjects()
        identifiersByType.removeAll()
    }

    // MARK: - Private methods

    private func store<Value: Storable>(_ object: Value) throws {
        let data = try encoder.encode(object)
        cache.setObject(
            CacheItem(data: data),
            forKey: cacheKey(for: Value.self, id: object.id) as NSString,
            cost: data.count
        )
        identifiersByType[Value.storageIdentifier, default: []].insert(object.id)
    }

    private func cacheKey(for type: (some Storable).Type, id: String) -> String {
        "\(type.storageIdentifier)::\(id)"
    }
}
