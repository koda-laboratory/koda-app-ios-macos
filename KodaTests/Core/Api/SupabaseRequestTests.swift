import Foundation
import Testing

@testable import Koda

@Suite("Supabase requests")
struct SupabaseRequestTests {
    private let baseURL = URL(string: "https://example.supabase.co")

    @Test("Password grant targets /auth/v1/token without the user's JWT")
    func passwordGrantRequest() async throws {
        let headers = SupabaseHeaderProvider(
            sessionProvider: StaticSessionTokenProvider(token: "user-jwt"),
            publishableKey: { "sb_publishable_test" }
        )
        let request = SupabaseRequest<AuthSessionResponseDTO>(
            path: "auth/v1/token",
            method: .post,
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: PasswordGrantRequestDTO(email: "a@b.c", password: "secret"),
            allowsSessionRecovery: false,
            sendsAuthorization: false,
            headerProvider: headers,
            baseURL: { baseURL }
        )

        let urlRequest = try await request.makeURLRequest()
        #expect(urlRequest.url?.absoluteString == "https://example.supabase.co/auth/v1/token?grant_type=password")
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == nil)
        let body = try #require(urlRequest.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json == ["email": "a@b.c", "password": "secret"])
    }

    @Test("Authenticated requests carry the bearer token")
    func authenticatedRequestCarriesBearer() async throws {
        let headers = SupabaseHeaderProvider(
            sessionProvider: StaticSessionTokenProvider(token: "user-jwt"),
            publishableKey: { "sb_publishable_test" }
        )
        let request = SupabaseRequest<EmptyHTTPResponse>(
            path: "auth/v1/logout",
            method: .post,
            headerProvider: headers,
            baseURL: { baseURL }
        )

        let urlRequest = try await request.makeURLRequest()
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer user-jwt")
    }

    @Test("A missing project URL fails before any network call")
    func missingProjectURL() async {
        let request = SupabaseRequest<EmptyHTTPResponse>(
            path: "auth/v1/logout",
            headerProvider: StaticHeaderProvider(),
            baseURL: { nil }
        )
        await #expect(throws: KodaError.self) { try await request.makeURLRequest() }
    }

    @Test("Session responses decode and map to UserSession")
    func decodesSession() throws {
        let json = """
            {"access_token":"a","token_type":"bearer","expires_in":3600,"expires_at":1800000000,
             "refresh_token":"r","user":{"id":"u-1","email":"a@b.c"}}
            """
        let request = SupabaseRequest<AuthSessionResponseDTO>(
            path: "auth/v1/token",
            headerProvider: StaticHeaderProvider(),
            baseURL: { baseURL }
        )
        let response = try #require(
            HTTPURLResponse(url: URL(fileURLWithPath: "/"), statusCode: 200, httpVersion: nil, headerFields: nil)
        )

        let dto = try request.decodeResponse(data: Data(json.utf8), response: response)
        let session = UserSession(fromDTO: dto)
        #expect(session.userId == "u-1")
        #expect(session.expiresAt == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(!session.needsRefresh(now: Date(timeIntervalSince1970: 1_700_000_000)))
    }

    @Test("Unsuccessful responses throw a mapped KodaError")
    func unsuccessfulResponseThrows() throws {
        let request = SupabaseRequest<AuthSessionResponseDTO>(
            path: "auth/v1/token",
            headerProvider: StaticHeaderProvider(),
            baseURL: { baseURL }
        )
        let response = try #require(
            HTTPURLResponse(url: URL(fileURLWithPath: "/"), statusCode: 400, httpVersion: nil, headerFields: nil)
        )
        let body = Data(#"{"error":"invalid_grant","error_description":"Invalid Refresh Token"}"#.utf8)

        let error = try #require(throws: KodaError.self) {
            try request.decodeResponse(data: body, response: response)
        }
        #expect(error.code == .invalidGrant)
    }
}
