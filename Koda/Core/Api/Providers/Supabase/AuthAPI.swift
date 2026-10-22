import Foundation

// MARK: - DTOs

struct PasswordGrantRequestDTO: Encodable, Sendable, Equatable {
    let email: String
    let password: String
}

struct RefreshTokenGrantRequestDTO: Encodable, Sendable, Equatable {
    let refreshToken: String

    private enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

/// GoTrue session returned by both token grants.
struct AuthSessionResponseDTO: Decodable, Sendable, Equatable {
    struct UserDTO: Decodable, Sendable, Equatable {
        let id: String
        let email: String?
    }

    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let expiresAt: Int?
    let refreshToken: String
    let user: UserDTO

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case user
    }
}

// MARK: - Requests

/// Typed requests to Supabase Auth (GoTrue, `/auth/v1`). Sign-up is disabled on the project.
enum AuthAPI {
    enum LogoutScope: String, Sendable {
        /// Only this device's session.
        case local
        /// Every session of the user.
        case global
    }

    /// `POST /auth/v1/token?grant_type=password`
    static func signIn(
        email: String,
        password: String,
        headerProvider: any HTTPHeaderProvider
    ) -> SupabaseRequest<AuthSessionResponseDTO> {
        SupabaseRequest(
            path: "auth/v1/token",
            method: .post,
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: PasswordGrantRequestDTO(email: email, password: password),
            errorHandling: .local,
            allowsSessionRecovery: false,
            sendsAuthorization: false,
            headerProvider: headerProvider
        )
    }

    /// `POST /auth/v1/token?grant_type=refresh_token`. The refresh token rotates on every use, so this must
    /// only run through the single-flight `HTTPSessionRecovery` / `RefreshSessionUseCase`.
    static func refreshSession(
        refreshToken: String,
        headerProvider: any HTTPHeaderProvider
    ) -> SupabaseRequest<AuthSessionResponseDTO> {
        SupabaseRequest(
            path: "auth/v1/token",
            method: .post,
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: RefreshTokenGrantRequestDTO(refreshToken: refreshToken),
            errorHandling: .suppressed,
            allowsSessionRecovery: false,
            sendsAuthorization: false,
            headerProvider: headerProvider
        )
    }

    /// `POST /auth/v1/logout?scope=…` with the user's JWT. Responds `204 No Content`.
    static func signOut(
        scope: LogoutScope = .local,
        headerProvider: any HTTPHeaderProvider
    ) -> SupabaseRequest<EmptyHTTPResponse> {
        SupabaseRequest(
            path: "auth/v1/logout",
            method: .post,
            queryItems: [URLQueryItem(name: "scope", value: scope.rawValue)],
            errorHandling: .suppressed,
            allowsSessionRecovery: false,
            headerProvider: headerProvider
        )
    }
}
