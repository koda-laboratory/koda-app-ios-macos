import Foundation

struct EmptyHTTPRequestBody: Encodable, Sendable {
}

struct EmptyHTTPResponse: Decodable, Sendable, Equatable {
}

/// Provider-neutral contract for one HTTP operation.
protocol HTTPRequest: Sendable {
    associatedtype Response: Decodable & Sendable

    var path: String { get }
    var method: HTTPMethod { get }
    var errorHandling: KodaErrorHandlingPolicy { get }
    var allowsSessionRecovery: Bool { get }

    func makeURLRequest() async throws -> URLRequest
    func decodeResponse(data: Data, response: HTTPURLResponse) throws -> Response
}
