import Foundation

protocol KeychainPersistentDataSource: StorableDataSource {}

actor KeychainStorableDataSource: KeychainPersistentDataSource {
    private struct Registry: Codable, Sendable {
        var identifiersByType: [String: Set<String>] = [:]
    }

    // MARK: - Properties

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let injectedKeychain: Keychain?
    private let namespace: String

    // MARK: - Lifecycle

    init(namespace: String = "com.kodalabs.app.storage") {
        self.injectedKeychain = nil
        self.namespace = namespace
    }

    init(keychain: Keychain, namespace: String = "com.kodalabs.app.storage") {
        self.injectedKeychain = keychain
        self.namespace = namespace
    }

    // MARK: - CRUD

    func create(_ object: some Storable) throws {
        try store(object)
    }

    func read<Value: Storable>(_ type: Value.Type, id: String) throws -> Value? {
        guard let encodedObject = try keychain().string(forKey: storageKey(for: type, id: id)),
            let data = encodedObject.data(using: .utf8)
        else {
            return nil
        }
        return try decoder.decode(type, from: data)
    }

    func readAll<Value: Storable>(_ type: Value.Type) throws -> [Value] {
        let identifiers = try readRegistry().identifiersByType[type.storageIdentifier] ?? []
        return try identifiers.compactMap { id in
            try read(type, id: id)
        }
    }

    func update(_ object: some Storable) throws {
        try store(object)
    }

    func delete(_ type: (some Storable).Type, id: String) throws {
        try keychain().removeValue(forKey: storageKey(for: type, id: id))

        var registry = try readRegistry()
        registry.identifiersByType[type.storageIdentifier]?.remove(id)
        try writeRegistry(registry)
    }

    func deleteAll(_ type: (some Storable).Type) throws {
        var registry = try readRegistry()
        let storageIdentifier = type.storageIdentifier

        for id in registry.identifiersByType[storageIdentifier] ?? [] {
            try keychain().removeValue(forKey: storageKey(for: type, id: id))
        }
        registry.identifiersByType[storageIdentifier] = nil
        try writeRegistry(registry)
    }

    func deleteStorage() throws {
        let registry = try readRegistry()
        for (storageIdentifier, identifiers) in registry.identifiersByType {
            for id in identifiers {
                try keychain().removeValue(
                    forKey: storageKey(storageIdentifier: storageIdentifier, id: id)
                )
            }
        }
        try keychain().removeValue(forKey: registryKey)
    }

    // MARK: - Private methods

    private var registryKey: String {
        "\(namespace).registry"
    }

    private func store<Value: Storable>(_ object: Value) throws {
        let data = try encoder.encode(object)
        guard let encodedObject = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                object,
                .init(codingPath: [], debugDescription: "The encoded value is not valid UTF-8.")
            )
        }

        try keychain().set(
            encodedObject,
            forKey: storageKey(for: Value.self, id: object.id),
            access: .firstUnlockThisDeviceOnly
        )

        var registry = try readRegistry()
        registry.identifiersByType[Value.storageIdentifier, default: []].insert(object.id)
        try writeRegistry(registry)
    }

    private func readRegistry() throws -> Registry {
        guard let encodedRegistry = try keychain().string(forKey: registryKey),
            let data = encodedRegistry.data(using: .utf8)
        else {
            return Registry()
        }
        return try decoder.decode(Registry.self, from: data)
    }

    private func writeRegistry(_ registry: Registry) throws {
        if registry.identifiersByType.isEmpty {
            try keychain().removeValue(forKey: registryKey)
            return
        }

        let data = try encoder.encode(registry)
        guard let encodedRegistry = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                registry,
                .init(codingPath: [], debugDescription: "The encoded registry is not valid UTF-8.")
            )
        }
        try keychain().set(encodedRegistry, forKey: registryKey, access: .firstUnlockThisDeviceOnly)
    }

    private func keychain() -> Keychain {
        injectedKeychain ?? .shared
    }

    private func storageKey(for type: (some Storable).Type, id: String) -> String {
        storageKey(storageIdentifier: type.storageIdentifier, id: id)
    }

    private func storageKey(storageIdentifier: String, id: String) -> String {
        "\(namespace).\(storageIdentifier).\(id)"
    }
}
