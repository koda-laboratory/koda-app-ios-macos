import Foundation

/// One typed request to the Supabase project: Auth (`/auth/v1/...`), PostgREST (`/rest/v1/...`) or the
/// `api` Edge Function (`/functions/v1/api/...`). Responses are plain JSON (no envelope); failures are decoded
/// with `SupabaseErrorResponse` into a `KodaError`.
struct SupabaseRequest<Response: Decodable & Sendable>: HTTPRequest {
    // MARK: - Properties

    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let body: (any Encodable & Sendable)?
    let timeout: TimeInterval
    let errorHandling: KodaErrorHandlingPolicy
    let allowsSessionRecovery: Bool
    /// `false` for endpoints that must not carry the user's JWT (for example the token grants).
    let sendsAuthorization: Bool

    private let baseURL: @Sendable () -> URL?
    private let headerProvider: any HTTPHeaderProvider
    private let extraHeaders: [String: String]

    // MARK: - Lifecycle

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: (any Encodable & Sendable)? = nil,
        timeout: TimeInterval = 30,
        errorHandling: KodaErrorHandlingPolicy = .automatic,
        allowsSessionRecovery: Bool = true,
        sendsAuthorization: Bool = true,
        extraHeaders: [String: String] = [:],
        headerProvider: any HTTPHeaderProvider,
        baseURL: @escaping @Sendable () -> URL? = { SupabaseEnvironment.projectURL }
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.timeout = timeout
        self.errorHandling = errorHandling
        self.allowsSessionRecovery = allowsSessionRecovery
        self.sendsAuthorization = sendsAuthorization
        self.extraHeaders = extraHeaders
        self.headerProvider = headerProvider
        self.baseURL = baseURL
    }

    // MARK: - HTTPRequest

    func makeURLRequest() async throws -> URLRequest {
        guard let baseURL = baseURL(),
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else {
            throw KodaError(
                type: .internal,
                reason: "SUPABASE_URL is not configured. Set it in Configuration/Koda.xcconfig."
            )
        }

        var pathComponents = components.path.split(separator: "/").map(String.init)
        pathComponents.append(contentsOf: path.split(separator: "/").map(String.init))
        components.path = "/" + pathComponents.joined(separator: "/")
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = method.rawValue

        var headers = await headerProvider.headers()
        if !sendsAuthorization {
            headers.removeValue(forKey: SupabaseHeaders.authorization)
        }
        headers.merge(extraHeaders) { _, requestValue in requestValue }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    func decodeResponse(data: Data, response: HTTPURLResponse) throws -> Response {
        guard (200...299).contains(response.statusCode) else {
            throw KodaErrorMapper.map(statusCode: response.statusCode, data: data)
        }

        if Response.self == EmptyHTTPResponse.self, let emptyResponse = EmptyHTTPResponse() as? Response {
            return emptyResponse
        }

        return try JSONDecoder.supabase().decode(Response.self, from: data)
    }
}
