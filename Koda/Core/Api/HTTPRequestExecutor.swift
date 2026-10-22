import Foundation

// MARK: - Protocol

/// Performs exactly one request attempt without publishing app-wide error actions.
protocol HTTPRequestExecuting: Sendable {
    @discardableResult
    func execute<Request: HTTPRequest>(_ request: Request) async throws(KodaError) -> Request.Response
}

// MARK: - Implementation

final class HTTPRequestExecutorImpl: HTTPRequestExecuting, Sendable {
    // MARK: - Properties

    private let httpLogger: any HTTPLogging
    private let transport: any HTTPTransport

    // MARK: - Lifecycle

    init(httpLogger: any HTTPLogging, transport: any HTTPTransport) {
        self.httpLogger = httpLogger
        self.transport = transport
    }

    // MARK: - Public Methods

    @discardableResult
    func execute<Request: HTTPRequest>(
        _ request: Request
    ) async throws(KodaError) -> Request.Response {
        let requestID = UUID()
        let startedAt = Date.now
        let context = HTTPRequestContext(method: request.method, path: request.path)
        let requestType = String(reflecting: Request.self)
        var urlRequest: URLRequest?

        do {
            let builtRequest = try await request.makeURLRequest()
            urlRequest = builtRequest
            let requestLog = HTTPRequestLog(
                id: requestID,
                date: startedAt,
                requestType: requestType,
                request: builtRequest
            )
            await httpLogger.log(.requestStarted(requestLog))

            let (data, response) = try await transport.data(for: builtRequest)
            let responseDate = Date.now
            let responseLog = HTTPResponseLog(
                id: requestID,
                date: responseDate,
                url: response.url?.absoluteString ?? builtRequest.url?.absoluteString ?? request.path,
                statusCode: response.statusCode,
                headers: headers(from: response),
                body: data,
                duration: responseDate.timeIntervalSince(startedAt)
            )
            await httpLogger.log(.responseReceived(responseLog))

            let decodedResponse = try request.decodeResponse(data: data, response: response)
            let decodedResponseLog = HTTPDecodedResponseLog(
                id: requestID,
                date: Date.now,
                model: String(reflecting: Request.Response.self),
                body: data,
                duration: Date.now.timeIntervalSince(startedAt)
            )
            await httpLogger.log(.responseDecoded(decodedResponseLog))

            return decodedResponse
        } catch {
            let mappedError = KodaErrorMapper.map(error).attach(context)
            let failureLog = HTTPFailureLog(
                id: requestID,
                date: Date.now,
                url: urlRequest?.url?.absoluteString,
                error: mappedError,
                duration: Date.now.timeIntervalSince(startedAt)
            )
            await httpLogger.log(.requestFailed(failureLog))

            throw mappedError
        }
    }

    // MARK: - Private Methods

    private func headers(from response: HTTPURLResponse) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: response.allHeaderFields.compactMap { key, value in
                guard let key = key as? String else { return nil }
                return (key, String(describing: value))
            }
        )
    }
}
