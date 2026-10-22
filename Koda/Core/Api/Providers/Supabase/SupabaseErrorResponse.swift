/// Tolerant decoder for the error bodies of every Supabase surface:
/// - GoTrue: `{ "code": 400, "error_code": "invalid_credentials", "msg": "…" }`
/// - GoTrue OAuth-style: `{ "error": "invalid_grant", "error_description": "…" }`
/// - PostgREST: `{ "code": "PGRST301", "message": "…", "details": …, "hint": … }`
/// - Edge Functions: `{ "error": "…", "message": "…" }` (contract owned by `koda-backend`)
struct SupabaseErrorResponse: Decodable, Sendable, Equatable {
    let code: String?
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case code
        case error
        case errorCode = "error_code"
        case errorDescription = "error_description"
        case message
        case msg
    }

    init(code: String?, message: String?) {
        self.code = code
        self.message = message
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let errorCode = try? container.decodeIfPresent(String.self, forKey: .errorCode)
        // `code` is the HTTP status (Int) in GoTrue and a string code in PostgREST.
        let stringCode = try? container.decodeIfPresent(String.self, forKey: .code)
        let error = try? container.decodeIfPresent(String.self, forKey: .error)

        let msg = try? container.decodeIfPresent(String.self, forKey: .msg)
        let message = try? container.decodeIfPresent(String.self, forKey: .message)
        let errorDescription = try? container.decodeIfPresent(String.self, forKey: .errorDescription)

        self.code = errorCode ?? stringCode ?? error
        self.message = msg ?? message ?? errorDescription ?? error
    }
}
