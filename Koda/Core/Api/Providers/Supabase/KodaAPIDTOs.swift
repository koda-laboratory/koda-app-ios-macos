import Foundation

// MARK: - Sync

/// One mutation of `POST /sync/push`.
struct SyncMutationDTO: Encodable, Sendable, Equatable {
    let table: String
    let id: String
    let op: String
    let fields: [String: JSONValue]?
    let clientTs: String

    private enum CodingKeys: String, CodingKey {
        case table
        case id
        case op
        case fields
        case clientTs = "client_ts"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(table, forKey: .table)
        try container.encode(id, forKey: .id)
        try container.encode(op, forKey: .op)
        try container.encodeIfPresent(fields, forKey: .fields)
        try container.encode(clientTs, forKey: .clientTs)
    }
}

struct SyncPushRequestDTO: Encodable, Sendable, Equatable {
    let deviceId: String?
    let mutations: [SyncMutationDTO]

    private enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case mutations
    }
}

struct SyncAppliedMutationDTO: Decodable, Sendable, Equatable {
    let table: String
    let id: String
    let serverSeq: Int64?
    let merged: Bool?

    private enum CodingKeys: String, CodingKey {
        case table
        case id
        case serverSeq = "server_seq"
        case merged
    }
}

struct SyncRejectedMutationDTO: Decodable, Sendable, Equatable {
    let table: String?
    /// The rejected id; `nil` when the server could not parse it.
    let id: String?
    let reason: String
    let serverSeq: Int64?
    let code: String?
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case table
        case id
        case reason
        case serverSeq = "server_seq"
        case code
        case message
    }

    init(table: String?, id: String?, reason: String, serverSeq: Int64?, code: String?, message: String?) {
        self.table = table
        self.id = id
        self.reason = reason
        self.serverSeq = serverSeq
        self.code = code
        self.message = message
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        table = try container.decodeIfPresent(String.self, forKey: .table)
        id = try? container.decodeIfPresent(String.self, forKey: .id)
        reason = try container.decode(String.self, forKey: .reason)
        serverSeq = try? container.decodeIfPresent(Int64.self, forKey: .serverSeq)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

struct SyncPushResponseDTO: Decodable, Sendable, Equatable {
    let applied: [SyncAppliedMutationDTO]
    let rejected: [SyncRejectedMutationDTO]
    let cursor: Int64?
}

struct SyncPullResponseDTO: Decodable, Sendable, Equatable {
    /// Complete rows per table name, tombstones included.
    let changes: [String: [[String: JSONValue]]]
    let cursor: Int64
    let hasMore: Bool
    let resetRequired: Bool

    private enum CodingKeys: String, CodingKey {
        case changes
        case cursor
        case hasMore = "has_more"
        case resetRequired = "reset_required"
    }

    init(changes: [String: [[String: JSONValue]]], cursor: Int64, hasMore: Bool, resetRequired: Bool) {
        self.changes = changes
        self.cursor = cursor
        self.hasMore = hasMore
        self.resetRequired = resetRequired
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        changes = try container.decodeIfPresent([String: [[String: JSONValue]]].self, forKey: .changes) ?? [:]
        cursor = try container.decode(Int64.self, forKey: .cursor)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        resetRequired = try container.decodeIfPresent(Bool.self, forKey: .resetRequired) ?? false
    }
}

// MARK: - Me

struct MeProfileDTO: Decodable, Sendable, Equatable {
    let id: String
    let displayName: String?
    let avatarEmoji: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarEmoji = "avatar_emoji"
    }
}

struct MeMemberDTO: Decodable, Sendable, Equatable {
    let userId: String
    let role: String
    let displayName: String?
    let avatarEmoji: String?

    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case displayName = "display_name"
        case avatarEmoji = "avatar_emoji"
    }
}

struct MeHouseholdDTO: Decodable, Sendable, Equatable {
    let id: String
    let name: String
    let timezone: String
    let role: String
    let members: [MeMemberDTO]
}

struct MeResponseDTO: Decodable, Sendable, Equatable {
    let userId: String
    let profile: MeProfileDTO?
    let households: [MeHouseholdDTO]

    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case profile
        case households
    }
}

// MARK: - Devices

struct DeviceRegistrationRequestDTO: Encodable, Sendable, Equatable {
    let id: String
    let apnsToken: String
    let platform: String
    let apnsEnv: String
    let appVersion: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case apnsToken = "apns_token"
        case platform
        case apnsEnv = "apns_env"
        case appVersion = "app_version"
    }
}

struct DeviceResponseDTO: Decodable, Sendable, Equatable {
    let id: String
}

// MARK: - Drafts

struct DraftActionResponseDTO: Decodable, Sendable, Equatable {
    let draftId: String
    let entries: Int

    private enum CodingKeys: String, CodingKey {
        case draftId = "draft_id"
        case entries
    }
}
