protocol HTTPHeaderProvider: Sendable {
    func headers() async -> [String: String]
}
