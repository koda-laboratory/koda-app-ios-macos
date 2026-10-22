protocol StorableDataSource: Sendable {
    func create(_ object: some Storable) async throws
    func read<Value: Storable>(_ type: Value.Type, id: String) async throws -> Value?
    func readAll<Value: Storable>(_ type: Value.Type) async throws -> [Value]
    func update(_ object: some Storable) async throws
    func delete(_ type: (some Storable).Type, id: String) async throws
    func deleteAll(_ type: (some Storable).Type) async throws
    func deleteStorage() async throws
}
