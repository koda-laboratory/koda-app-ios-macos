import Foundation

import OSLog

protocol LoggerService: Sendable {
    func debug(
        _ message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    )
    func error(
        _ message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    )
    func fault(
        _ message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    )
    func info(
        _ message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    )
    func warning(
        _ message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    )
}

extension LoggerService {
    func debug(
        _ message: String,
        attributes: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        debug(message, attributes: attributes, file: file, function: function, line: line)
    }

    func error(
        _ message: String,
        attributes: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        error(message, attributes: attributes, file: file, function: function, line: line)
    }

    func fault(
        _ message: String,
        attributes: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        fault(message, attributes: attributes, file: file, function: function, line: line)
    }

    func info(
        _ message: String,
        attributes: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        info(message, attributes: attributes, file: file, function: function, line: line)
    }

    func warning(
        _ message: String,
        attributes: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        warning(message, attributes: attributes, file: file, function: function, line: line)
    }
}

final class LoggerServiceImpl: LoggerService, Sendable {
    private let subsystem: String

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.kodalabs.app") {
        self.subsystem = subsystem
    }

    func debug(
        _ message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    ) {
        write(.debug, message: message, attributes: attributes, file: file, function: function, line: line)
    }

    func error(
        _ message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    ) {
        write(.error, message: message, attributes: attributes, file: file, function: function, line: line)
    }

    func fault(
        _ message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    ) {
        write(.fault, message: message, attributes: attributes, file: file, function: function, line: line)
    }

    func info(
        _ message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    ) {
        write(.info, message: message, attributes: attributes, file: file, function: function, line: line)
    }

    func warning(
        _ message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    ) {
        write(.warning, message: message, attributes: attributes, file: file, function: function, line: line)
    }

    private func write(
        _ level: LoggerLevel,
        message: String,
        attributes: [String: String],
        file: String,
        function: String,
        line: UInt
    ) {
        let source = LogSource(file: file, function: function, line: line)
        let logger = Logger(subsystem: subsystem, category: source.category)
        let renderedMessage = formatted(message, attributes: attributes, source: source)

        writeToConsole(level, message: renderedMessage, logger: logger)
    }

    private func writeToConsole(_ level: LoggerLevel, message: String, logger: Logger) {
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .fault:
            logger.fault("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        }
    }

    private func formatted(
        _ message: String,
        attributes: [String: String],
        source: LogSource
    ) -> String {
        let context = "[\(source.fileName):\(source.line) \(source.function)]"
        guard !attributes.isEmpty else { return "\(context) \(message)" }

        let renderedAttributes = attributes.keys.sorted().map { key in
            "\(key)=\(attributes[key] ?? "")"
        }.joined(separator: " ")
        return "\(context) \(message) | \(renderedAttributes)"
    }
}

private struct LogSource {
    let fileName: String
    let function: String
    let line: UInt

    var category: String {
        fileName.replacingOccurrences(of: ".swift", with: "")
    }

    init(file: String, function: String, line: UInt) {
        self.fileName = URL(fileURLWithPath: file).lastPathComponent
        self.function = function
        self.line = line
    }
}

private enum LoggerLevel {
    case debug
    case error
    case fault
    case info
    case warning
}
