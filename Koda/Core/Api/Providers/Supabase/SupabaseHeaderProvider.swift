/// Supplies the bearer token of the signed-in user.
protocol SessionTokenProviding: Sendable {
    func accessToken() async -> String?
}

/// Headers required by every Supabase request: the publishable `apikey`, JSON content negotiation, client
/// info and, when there is a session, the user's JWT.
final class SupabaseHeaderProvider: HTTPHeaderProvider, Sendable {
    private let publishableKey: @Sendable () -> String?
    private let sessionProvider: any SessionTokenProviding

    init(
        sessionProvider: any SessionTokenProviding,
        publishableKey: @escaping @Sendable () -> String? = { SupabaseEnvironment.publishableKey }
    ) {
        self.sessionProvider = sessionProvider
        self.publishableKey = publishableKey
    }

    func headers() async -> [String: String] {
        var headers = [
            SupabaseHeaders.accept: "application/json",
            SupabaseHeaders.contentType: "application/json;charset=UTF-8",
            SupabaseHeaders.clientInfo:
                "koda-\(PlatformInfo.platformName)/\(PlatformInfo.appVersion) (\(PlatformInfo.operatingSystemVersion))",
        ]

        if let publishableKey = publishableKey() {
            headers[SupabaseHeaders.apiKey] = publishableKey
        }
        if let token = await sessionProvider.accessToken(), !token.isEmpty {
            headers[SupabaseHeaders.authorization] = "Bearer \(token)"
        }

        return headers
    }
}
