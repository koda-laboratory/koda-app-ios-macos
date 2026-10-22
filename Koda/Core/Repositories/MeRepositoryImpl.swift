import Foundation
import GRDB

final class MeRepositoryImpl: MeRepository, Sendable {
    // MARK: - Properties

    private let remoteDataSource: any MeRemoteDataSource
    private let database: AppDatabase
    private let clock: @Sendable () -> Date

    // MARK: - Lifecycle

    init(
        remoteDataSource: any MeRemoteDataSource,
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.remoteDataSource = remoteDataSource
        self.database = database
        self.clock = clock
    }

    // MARK: - Public Methods

    @discardableResult
    func refresh() async throws(KodaError) -> HouseholdContext {
        let dto = try await remoteDataSource.fetchMe()
        guard !dto.households.isEmpty else {
            throw KodaError(type: .forbidden, reason: "The user does not belong to any household.")
        }
        let fetchedAt = ISO8601Timestamp.string(from: clock())

        try await database.write { db in
            try db.execute(sql: "DELETE FROM me_members")
            try db.execute(sql: "DELETE FROM me_households")
            try db.execute(sql: "DELETE FROM me_profile")
            try MeProfileRecord(
                userId: dto.userId.lowercased(),
                displayName: dto.profile?.displayName,
                avatarEmoji: dto.profile?.avatarEmoji,
                fetchedAt: fetchedAt
            )
            .insert(db)
            for (position, household) in dto.households.enumerated() {
                try MeHouseholdRecord(
                    id: household.id.lowercased(),
                    name: household.name,
                    timezone: household.timezone,
                    role: household.role,
                    position: position
                )
                .insert(db)
                for (memberPosition, member) in household.members.enumerated() {
                    try MeMemberRecord(
                        householdId: household.id.lowercased(),
                        userId: member.userId.lowercased(),
                        role: member.role,
                        displayName: member.displayName,
                        avatarEmoji: member.avatarEmoji,
                        position: memberPosition
                    )
                    .insert(db)
                }
            }
            // The first household owns every row this app creates.
            try db.execute(
                sql: "UPDATE sync_state SET household_id = ? WHERE id = 1",
                arguments: [dto.households[0].id.lowercased()]
            )
        }

        guard let context = try await cached() else {
            throw KodaError(type: .storage, reason: "The cached household could not be read back.")
        }
        return context
    }

    func cached() async throws(KodaError) -> HouseholdContext? {
        try await database.read(Self.fetchContext)
    }

    func observe() -> AsyncStream<HouseholdContext?> {
        database.observe(Self.fetchContext)
    }

    // MARK: - Mapping

    @Sendable
    private static func fetchContext(_ db: Database) throws -> HouseholdContext? {
        guard let profile = try MeProfileRecord.fetchOne(db),
            let userID = UUID(uuidString: profile.userId),
            let householdID = try SyncStateRecord.fetch(db).householdId,
            let household = try MeHouseholdRecord.fetchOne(db, key: householdID),
            let id = UUID(uuidString: household.id)
        else {
            return nil
        }
        let members =
            try MeMemberRecord
            .filter(Column("household_id") == household.id)
            .order(Column("position"))
            .fetchAll(db)
            .compactMap { member -> HouseholdMember? in
                guard let memberID = UUID(uuidString: member.userId) else { return nil }
                return HouseholdMember(
                    userID: memberID,
                    role: HouseholdRole(rawValue: member.role) ?? .member,
                    displayName: member.displayName,
                    avatarEmoji: member.avatarEmoji
                )
            }
        return HouseholdContext(
            userID: userID,
            displayName: profile.displayName,
            avatarEmoji: profile.avatarEmoji,
            household: Household(
                id: id,
                name: household.name,
                timeZone: TimeZone(identifier: household.timezone) ?? .household,
                role: HouseholdRole(rawValue: household.role) ?? .member,
                members: members
            )
        )
    }
}
