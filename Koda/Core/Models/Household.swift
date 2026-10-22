import Foundation

enum HouseholdRole: String, Sendable, Codable {
    case owner
    case member
}

struct HouseholdMember: Sendable, Equatable, Identifiable {
    let userID: UUID
    let role: HouseholdRole
    let displayName: String?
    let avatarEmoji: String?

    var id: UUID { userID }
}

struct Household: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let timeZone: TimeZone
    let role: HouseholdRole
    let members: [HouseholdMember]
    var settings: HouseholdSettings = .default
}

/// The signed-in user and the household every new row belongs to (cached from `GET /me`).
struct HouseholdContext: Sendable, Equatable {
    let userID: UUID
    let displayName: String?
    let avatarEmoji: String?
    let household: Household
}
