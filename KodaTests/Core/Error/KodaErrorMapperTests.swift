import Foundation
import Testing

@testable import Koda

@Suite("KodaErrorMapper")
struct KodaErrorMapperTests {
    @Test(
        "URL errors map to network categories",
        arguments: [
            (URLError.Code.notConnectedToInternet, KodaErrorType.noInternet),
            (.networkConnectionLost, .noInternet),
            (.timedOut, .apiTimeout),
            (.cancelled, .apiRequestCancelled),
            (.serverCertificateUntrusted, .unsecureConnection),
            (.badServerResponse, .apiUnknown),
        ]
    )
    func mapsURLErrors(code: URLError.Code, expectedType: KodaErrorType) {
        #expect(KodaErrorMapper.map(URLError(code)).type == expectedType)
    }

    @Test("Cancellation is ignored and decoding failures are parse errors")
    func mapsSwiftErrors() throws {
        let cancellation = KodaErrorMapper.map(CancellationError())
        #expect(cancellation.type == .apiRequestCancelled)
        #expect(cancellation.action == .ignore)

        let decodingError = try #require(
            throws: DecodingError.self,
            performing: { try JSONDecoder().decode(Int.self, from: Data("\"x\"".utf8)) }
        )
        #expect(KodaErrorMapper.map(decodingError).type == .badModelParse)
    }

    @Test("A KodaError passes through unchanged")
    func keepsKodaErrors() {
        let error = KodaError(type: .conflict, reason: "Conflict", rawCode: "x", statusCode: 409)
        #expect(KodaErrorMapper.map(error) == error)
    }

    @Test("GoTrue invalid credentials are presented, not recovered")
    func mapsGoTrueInvalidCredentials() {
        let body = Data(#"{"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#.utf8)
        let error = KodaErrorMapper.map(statusCode: 400, data: body)

        #expect(error.code == .invalidCredentials)
        #expect(error.type == .auth)
        #expect(error.reason == "Invalid login credentials")
        #expect(error.action == .present)
        #expect(error.localizedPresentationKey == "error.code.invalid-credentials")
    }

    @Test("OAuth-style invalid_grant forces login")
    func mapsInvalidGrant() {
        let body = Data(#"{"error":"invalid_grant","error_description":"Invalid Refresh Token"}"#.utf8)
        let error = KodaErrorMapper.map(statusCode: 400, data: body)

        #expect(error.code == .invalidGrant)
        #expect(error.reason == "Invalid Refresh Token")
        #expect(error.action == .forceLogin)
        #expect(error.invalidatesSession)
    }

    @Test("An expired JWT triggers session recovery")
    func mapsExpiredJWT() {
        let postgrest = KodaErrorMapper.map(
            statusCode: 401,
            data: Data(#"{"code":"PGRST303","message":"JWT expired","details":null,"hint":null}"#.utf8)
        )
        #expect(postgrest.code == .postgrestJWTExpired)
        #expect(postgrest.action == .reauthenticate)

        let unknown401 = KodaErrorMapper.map(statusCode: 401, data: Data("not json".utf8))
        #expect(unknown401.type == .auth)
        #expect(unknown401.action == .reauthenticate)
    }

    @Test(
        "HTTP statuses without a body map to categories",
        arguments: [
            (403, KodaErrorType.forbidden), (404, .notFound), (409, .conflict), (429, .rateLimited),
            (500, .server), (503, .server), (418, .apiUnknown),
        ]
    )
    func mapsStatusCodes(statusCode: Int, expectedType: KodaErrorType) {
        let error = KodaErrorMapper.map(statusCode: statusCode, data: Data())
        #expect(error.type == expectedType)
        #expect(error.statusCode == statusCode)
        #expect(error.action == .present)
    }

    @Test("Offline errors never invalidate the session")
    func offlineKeepsSession() {
        #expect(!KodaErrorMapper.map(URLError(.notConnectedToInternet)).invalidatesSession)
    }
}
