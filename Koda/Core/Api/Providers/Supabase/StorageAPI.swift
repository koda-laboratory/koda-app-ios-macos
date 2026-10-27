import Foundation

/// Supabase Storage objects of the private image buckets (`/storage/v1/object/...`, see `ImageBucket`). Paths are
/// `<household>/<owner>/<uuid>.<ext>`; the buckets' policies only allow the folders of the user's households.
enum StorageAPI {
    /// `POST /object/<bucket>/<path>` with `x-upsert` (a retried upload of the same file overwrites it).
    static func upload(
        bucket: ImageBucket,
        path: String,
        data: Data,
        contentType: String,
        headerProvider: any HTTPHeaderProvider
    ) -> StorageRequest {
        StorageRequest(
            path: "storage/v1/object/\(bucket.rawValue)/\(path)",
            method: .post,
            body: data,
            extraHeaders: [SupabaseHeaders.contentType: contentType, "x-upsert": "true"],
            timeout: 120,
            headerProvider: headerProvider
        )
    }

    /// `GET /object/authenticated/<bucket>/<path>`: the bytes, with the user's JWT.
    static func download(
        bucket: ImageBucket,
        path: String,
        headerProvider: any HTTPHeaderProvider
    ) -> StorageRequest {
        StorageRequest(
            path: "storage/v1/object/authenticated/\(bucket.rawValue)/\(path)",
            method: .get,
            body: nil,
            extraHeaders: [SupabaseHeaders.accept: "*/*"],
            timeout: 60,
            headerProvider: headerProvider
        )
    }
}

/// A Storage request with a raw body and a raw response (images, not JSON).
struct StorageRequest: HTTPRequest {
    typealias Response = Data

    let path: String
    let method: HTTPMethod
    let body: Data?
    let extraHeaders: [String: String]
    let timeout: TimeInterval
    let headerProvider: any HTTPHeaderProvider
    var errorHandling: KodaErrorHandlingPolicy { .suppressed }
    var allowsSessionRecovery: Bool { true }

    func makeURLRequest() async throws -> URLRequest {
        guard let baseURL = SupabaseEnvironment.projectURL else {
            throw KodaError(
                type: .internal,
                reason: "SUPABASE_URL is not configured. Set it in Configuration/Koda.xcconfig."
            )
        }
        let url = path.split(separator: "/").reduce(baseURL) { url, component in
            url.appending(path: String(component))
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = method.rawValue
        var headers = await headerProvider.headers()
        headers.merge(extraHeaders) { _, requestValue in requestValue }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = body
        return request
    }

    func decodeResponse(data: Data, response: HTTPURLResponse) throws -> Data {
        guard (200...299).contains(response.statusCode) else {
            throw KodaErrorMapper.map(statusCode: response.statusCode, data: data)
        }
        return data
    }
}
