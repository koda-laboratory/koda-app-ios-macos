import Foundation

/// Credentials of the signed-in user, persisted in the shared Keychain.
struct UserSession: Codable, Sendable, Equatable {
    let userId: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    /// `true` when the access token expires within `leeway`, so a proactive refresh is worth it.
    func needsRefresh(now: Date = .now, leeway: TimeInterval = 60) -> Bool {
        expiresAt <= now.addingTimeInterval(leeway)
    }
}

extension UserSession {
    init(fromDTO dto: AuthSessionResponseDTO, now: Date = .now) {
        let expiresAt =
            dto.expiresAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            ?? now.addingTimeInterval(TimeInterval(dto.expiresIn))
        self.init(
            userId: dto.user.id,
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
            expiresAt: expiresAt
        )
    }
}
