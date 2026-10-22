import Foundation

enum KodaErrorMapper {
    // MARK: - Public Methods

    static func map(_ error: any Error) -> KodaError {
        switch error {
        case let error as KodaError:
            return error

        case is CancellationError:
            return KodaError(type: .apiRequestCancelled, reason: "The request was cancelled.")

        case is DecodingError:
            return KodaError(type: .badModelParse, reason: String(describing: error))

        case let error as URLError:
            return map(error)

        case let error as KeychainError:
            return KodaError(type: .storage, reason: error.description)

        default:
            return KodaError(type: .apiUnknown, reason: String(describing: error))
        }
    }

    /// Maps an unsuccessful Supabase response (GoTrue, PostgREST or Edge Function) to a `KodaError`.
    static func map(statusCode: Int, data: Data) -> KodaError {
        let response = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data)
        let type =
            if let code = response?.code.flatMap(KodaErrorCode.init(rawValue:)) {
                errorType(for: code, statusCode: statusCode)
            } else {
                KodaErrorType(statusCode: statusCode)
            }

        return KodaError(
            type: type,
            reason: response?.message ?? "The server returned HTTP status \(statusCode).",
            rawCode: response?.code,
            statusCode: statusCode
        )
    }

    // MARK: - Private Methods

    private static func errorType(for code: KodaErrorCode, statusCode: Int) -> KodaErrorType {
        switch code {
        case .overRequestRateLimit:
            .rateLimited
        case .validationFailed:
            .badRequest
        default:
            .auth
        }
    }

    private static func map(_ error: URLError) -> KodaError {
        let type: KodaErrorType =
            switch error.code {
            case .cancelled:
                .apiRequestCancelled
            case .timedOut:
                .apiTimeout
            case .cannotConnectToHost, .cannotFindHost, .dataNotAllowed, .networkConnectionLost,
                .notConnectedToInternet, .internationalRoamingOff:
                .noInternet
            case .appTransportSecurityRequiresSecureConnection, .clientCertificateRejected,
                .clientCertificateRequired, .secureConnectionFailed, .serverCertificateHasBadDate,
                .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid,
                .serverCertificateUntrusted:
                .unsecureConnection
            default:
                .apiUnknown
            }

        return KodaError(type: type, reason: error.localizedDescription)
    }
}
