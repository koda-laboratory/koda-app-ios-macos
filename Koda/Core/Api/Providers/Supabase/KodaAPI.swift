import Foundation

/// Typed requests to the `api` Edge Function (`/functions/v1/api/...`). The contract is owned by
/// `koda-backend` (`supabase/functions/api/app.ts`, `_shared/validation.ts`). Every route sends the user's JWT
/// and allows single-flight session recovery.
enum KodaAPI {
    static let basePath = "functions/v1/api"

    /// `GET /me`: profile, households and members.
    static func me(headerProvider: any HTTPHeaderProvider) -> SupabaseRequest<MeResponseDTO> {
        SupabaseRequest(path: "\(basePath)/me", errorHandling: .local, headerProvider: headerProvider)
    }

    /// `POST /sync/push` (at most 500 mutations; the app sends batches of 100).
    static func syncPush(
        _ body: SyncPushRequestDTO,
        headerProvider: any HTTPHeaderProvider
    ) -> SupabaseRequest<SyncPushResponseDTO> {
        SupabaseRequest(
            path: "\(basePath)/sync/push",
            method: .post,
            body: body,
            timeout: 60,
            errorHandling: .suppressed,
            headerProvider: headerProvider
        )
    }

    /// `GET /sync/pull?cursor=N&limit=L` (limit 1…1000).
    static func syncPull(
        cursor: Int64,
        limit: Int,
        headerProvider: any HTTPHeaderProvider
    ) -> SupabaseRequest<SyncPullResponseDTO> {
        SupabaseRequest(
            path: "\(basePath)/sync/pull",
            queryItems: [
                URLQueryItem(name: "cursor", value: String(cursor)),
                URLQueryItem(name: "limit", value: String(limit)),
            ],
            timeout: 60,
            errorHandling: .suppressed,
            headerProvider: headerProvider
        )
    }

    /// `PUT /devices`: registers or refreshes this installation's APNs token.
    static func registerDevice(
        _ body: DeviceRegistrationRequestDTO,
        headerProvider: any HTTPHeaderProvider
    ) -> SupabaseRequest<DeviceResponseDTO> {
        SupabaseRequest(
            path: "\(basePath)/devices",
            method: .put,
            body: body,
            errorHandling: .suppressed,
            headerProvider: headerProvider
        )
    }

    /// `DELETE /devices/:id` (204, or 404 when unknown).
    static func unregisterDevice(
        id: String,
        headerProvider: any HTTPHeaderProvider
    ) -> SupabaseRequest<EmptyHTTPResponse> {
        SupabaseRequest(
            path: "\(basePath)/devices/\(id)",
            method: .delete,
            errorHandling: .suppressed,
            headerProvider: headerProvider
        )
    }

    /// `POST /drafts/:id/accept` (404 unknown, 409 not pending).
    static func acceptDraft(
        id: String,
        headerProvider: any HTTPHeaderProvider
    ) -> SupabaseRequest<DraftActionResponseDTO> {
        SupabaseRequest(
            path: "\(basePath)/drafts/\(id)/accept",
            method: .post,
            errorHandling: .local,
            headerProvider: headerProvider
        )
    }

    /// `POST /drafts/:id/discard` (404 unknown, 409 not pending).
    static func discardDraft(
        id: String,
        headerProvider: any HTTPHeaderProvider
    ) -> SupabaseRequest<DraftActionResponseDTO> {
        SupabaseRequest(
            path: "\(basePath)/drafts/\(id)/discard",
            method: .post,
            errorHandling: .local,
            headerProvider: headerProvider
        )
    }
}
