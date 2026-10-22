import Foundation

// MARK: - Models

enum HTTPLogEventKind: Sendable, Equatable {
    case requestStarted
    case responseDecoded
    case responseReceived
    case requestFailed
}

struct HTTPRequestLog: Sendable, Equatable {
    let id: UUID
    let date: Date
    let requestType: String
    let method: String
    let url: String
    let headers: [String: String]
    let body: Data?
    let timeout: TimeInterval

    init(id: UUID, date: Date, requestType: String, request: URLRequest) {
        self.id = id
        self.date = date
        self.requestType = requestType
        self.method = request.httpMethod ?? "UNKNOWN"
        self.url = request.url?.absoluteString ?? "UNKNOWN"
        self.headers = request.allHTTPHeaderFields ?? [:]
        self.body = request.httpBody
        self.timeout = request.timeoutInterval
    }
}

struct HTTPResponseLog: Sendable, Equatable {
    let id: UUID
    let date: Date
    let url: String
    let statusCode: Int
    let headers: [String: String]
    let body: Data
    let duration: TimeInterval
}

struct HTTPDecodedResponseLog: Sendable, Equatable {
    let id: UUID
    let date: Date
    let model: String
    let body: Data?
    let duration: TimeInterval
}

struct HTTPFailureLog: Sendable, Equatable {
    let id: UUID
    let date: Date
    let url: String?
    let error: KodaError
    let duration: TimeInterval
}

enum HTTPLogEvent: Sendable, Equatable {
    case requestStarted(HTTPRequestLog)
    case responseReceived(HTTPResponseLog)
    case responseDecoded(HTTPDecodedResponseLog)
    case requestFailed(HTTPFailureLog)

    var kind: HTTPLogEventKind {
        switch self {
        case .requestStarted:
            .requestStarted
        case .responseReceived:
            .responseReceived
        case .responseDecoded:
            .responseDecoded
        case .requestFailed:
            .requestFailed
        }
    }
}

// MARK: - Protocol

protocol HTTPLogging: Sendable {
    func log(_ event: HTTPLogEvent) async
}

// MARK: - Configuration

struct HTTPLoggerConfiguration: Sendable {
    let isEnabled: Bool
    let logsRequestHeaders: Bool
    let logsResponseHeaders: Bool
    let logsBodies: Bool
    let logsDecodedValues: Bool
    let maximumValueLength: Int
    let sensitiveKeys: Set<String>

    static let disabled = Self(isEnabled: false)
    static let verbose = Self(logsDecodedValues: false)

    static var currentEnvironment: Self {
        SupabaseEnvironment.isHTTPLoggingEnabled ? .verbose : .disabled
    }

    init(
        isEnabled: Bool = true,
        logsRequestHeaders: Bool = true,
        logsResponseHeaders: Bool = true,
        logsBodies: Bool = true,
        logsDecodedValues: Bool = true,
        maximumValueLength: Int = 20_000,
        sensitiveKeys: Set<String> = [
            "apikey", "authorization", "cookie", "password", "refresh_token", "refreshtoken", "secret", "token",
        ]
    ) {
        self.isEnabled = isEnabled
        self.logsRequestHeaders = logsRequestHeaders
        self.logsResponseHeaders = logsResponseHeaders
        self.logsBodies = logsBodies
        self.logsDecodedValues = logsDecodedValues
        self.maximumValueLength = maximumValueLength
        self.sensitiveKeys = sensitiveKeys
    }
}

// MARK: - Implementation

/// HTTP logger backed by the app-wide `LoggerService`.
actor HTTPLoggerImpl: HTTPLogging {
    private let configuration: HTTPLoggerConfiguration
    private let dateFormatter = ISO8601DateFormatter()
    private let loggerService: any LoggerService
    private let redactor: HTTPLogRedactor

    init(
        configuration: HTTPLoggerConfiguration,
        loggerService: any LoggerService
    ) {
        self.configuration = configuration
        self.loggerService = loggerService
        self.redactor = HTTPLogRedactor(configuration: configuration)
    }

    func log(_ event: HTTPLogEvent) {
        guard configuration.isEnabled else { return }

        switch event {
        case .requestStarted(let request):
            writeInfo(format(request))
        case .responseReceived(let response):
            writeInfo(format(response))
        case .responseDecoded(let response):
            writeInfo(format(response))
        case .requestFailed(let failure):
            writeError(format(failure))
        }
    }

    private func format(_ request: HTTPRequestLog) -> String {
        var sections = [
            "🚀 [HTTP][REQUEST] #\(shortID(request.id))",
            "🕐 Started: \(dateFormatter.string(from: request.date))",
            "🧩 Request: \(request.requestType)",
            "➡️ \(request.method) \(request.url)",
            "⏱️ Timeout: \(formattedSeconds(request.timeout))",
        ]

        if configuration.logsRequestHeaders {
            sections.append("📤 Headers:\n\(formattedHeaders(request.headers))")
        }
        if configuration.logsBodies {
            sections.append("📦 Request body:\n\(formattedBody(request.body))")
        }

        return sections.joined(separator: "\n")
    }

    private func format(_ response: HTTPResponseLog) -> String {
        var sections = [
            "🌍 [HTTP][RESPONSE] #\(shortID(response.id))",
            "🕐 Received: \(dateFormatter.string(from: response.date))",
            "⬅️ HTTP \(response.statusCode) \(response.url)",
            "⏱️ Duration: \(formattedMilliseconds(response.duration))",
        ]

        if configuration.logsResponseHeaders {
            sections.append("📥 Headers:\n\(formattedHeaders(response.headers))")
        }
        if configuration.logsBodies {
            sections.append("📦 Response body:\n\(formattedBody(response.body))")
        }

        return sections.joined(separator: "\n")
    }

    private func format(_ response: HTTPDecodedResponseLog) -> String {
        var sections = [
            "✅ [HTTP][DECODED] #\(shortID(response.id))",
            "🕐 Decoded: \(dateFormatter.string(from: response.date))",
            "🧩 Model: \(response.model)",
            "⏱️ Total duration: \(formattedMilliseconds(response.duration))",
        ]

        if configuration.logsDecodedValues {
            sections.append("📦 Decoded value:\n\(formattedBody(response.body))")
        }

        return sections.joined(separator: "\n")
    }

    private func format(_ failure: HTTPFailureLog) -> String {
        let error = failure.error
        return [
            "❌ [HTTP][ERROR] #\(shortID(failure.id))",
            "🕐 Failed: \(dateFormatter.string(from: failure.date))",
            "➡️ \(error.context?.method.rawValue ?? "UNKNOWN") \(failure.url ?? error.context?.path ?? "UNKNOWN")",
            "⏱️ Duration: \(formattedMilliseconds(failure.duration))",
            "🏷️ Type: \(error.type.rawValue)",
            "🔢 Code: \(error.rawCode ?? "none")",
            "🌐 Status: \(error.statusCode.map(String.init) ?? "none")",
            "💬 Reason: \(error.reason)",
        ].joined(separator: "\n")
    }

    private func formattedHeaders(_ headers: [String: String]) -> String {
        redactor.headers(headers)
    }

    private func formattedBody(_ data: Data?) -> String {
        redactor.body(data)
    }

    private func shortID(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }

    private func formattedSeconds(_ value: TimeInterval) -> String {
        String(format: "%.1f s", value)
    }

    private func formattedMilliseconds(_ value: TimeInterval) -> String {
        String(format: "%.0f ms", value * 1_000)
    }

    private func writeInfo(_ message: String) {
        loggerService.info(message, attributes: ["log.category": "HTTP"])
    }

    private func writeError(_ message: String) {
        loggerService.error(message, attributes: ["log.category": "HTTP"])
    }
}

struct HTTPLogRedactor: Sendable {
    private let maximumValueLength: Int
    private let sensitiveKeys: Set<String>

    init(configuration: HTTPLoggerConfiguration = .verbose) {
        self.maximumValueLength = configuration.maximumValueLength
        self.sensitiveKeys = configuration.sensitiveKeys
    }

    func headers(_ headers: [String: String]) -> String {
        guard !headers.isEmpty else { return "∅" }

        return headers.keys.sorted().map { key in
            let value = isSensitive(key) ? "<redacted>" : headers[key] ?? ""
            return "\(key): \(value)"
        }.joined(separator: "\n")
    }

    func body(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "∅" }

        guard let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let redactedData = try? JSONSerialization.data(
                withJSONObject: redactedJSON(object),
                options: [.prettyPrinted, .sortedKeys]
            ),
            let value = String(data: redactedData, encoding: .utf8)
        else {
            return "<\(data.count) non-JSON bytes>"
        }

        return truncated(value)
    }

    private func redactedJSON(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues { nestedValue in
                redactedJSON(nestedValue)
            }.reduce(into: [String: Any]()) { result, entry in
                result[entry.key] = isSensitive(entry.key) ? "<redacted>" : entry.value
            }
        }
        if let array = value as? [Any] {
            return array.map(redactedJSON)
        }
        return value
    }

    private func isSensitive(_ key: String) -> Bool {
        let normalizedKey = key.lowercased().replacingOccurrences(of: "-", with: "_")
        return sensitiveKeys.contains { sensitiveKey in
            normalizedKey.contains(sensitiveKey)
        }
    }

    private func truncated(_ value: String) -> String {
        guard value.count > maximumValueLength else { return value }
        return String(value.prefix(maximumValueLength)) + "\n… <truncated>"
    }
}
