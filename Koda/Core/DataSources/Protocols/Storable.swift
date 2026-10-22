protocol Storable: Codable, Sendable, Identifiable where ID == String {
    /// Stable namespace used by every storage implementation. Never derive it from type reflection.
    static var storageIdentifier: String { get }
}
