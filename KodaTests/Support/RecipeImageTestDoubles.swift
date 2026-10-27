import CoreGraphics
import Foundation
import ImageIO
import Synchronization
import UniformTypeIdentifiers

@testable import Koda

/// Image files in memory, by bucket and Storage path.
final class InMemoryRecipeImageFiles: RecipeImageFileDataSource, Sendable {
    private struct Key: Hashable {
        let bucket: ImageBucket
        let path: String
    }

    private let files = Mutex<[Key: Data]>([:])

    /// Paths of every bucket.
    var paths: [String] { files.withLock { $0.keys.map(\.path).sorted() } }

    func paths(in bucket: ImageBucket) -> [String] {
        files.withLock { $0.keys.filter { $0.bucket == bucket }.map(\.path).sorted() }
    }

    func data(at path: String, bucket: ImageBucket) -> Data? {
        files.withLock { $0[Key(bucket: bucket, path: path)] }
    }

    func fileURL(at path: String, bucket: ImageBucket) -> URL? {
        data(at: path, bucket: bucket) == nil ? nil : URL(filePath: "/tmp/koda-tests/\(bucket.rawValue)/\(path)")
    }

    func write(_ data: Data, at path: String, bucket: ImageBucket) throws(KodaError) {
        files.withLock { $0[Key(bucket: bucket, path: path)] = data }
    }

    func remove(at path: String, bucket: ImageBucket) {
        _ = files.withLock { $0.removeValue(forKey: Key(bucket: bucket, path: path)) }
    }

    func removeAll() { files.withLock { $0.removeAll() } }
}

/// Storage that records uploads (with their bucket) and can fail a number of times first.
final class FakeRecipeImageRemote: RecipeImageRemoteDataSource, Sendable {
    private struct State {
        var uploads: [(path: String, bucket: ImageBucket)] = []
        var failuresLeft = 0
        /// By `<bucket>/<path>`.
        var objects: [String: Data] = [:]
    }

    private let state = Mutex(State())

    init(failures: Int = 0, objects: [String: Data] = [:]) {
        state.withLock {
            $0.failuresLeft = failures
            $0.objects = objects
        }
    }

    var uploads: [String] { state.withLock { $0.uploads.map(\.path) } }
    var uploadedBuckets: [ImageBucket] { state.withLock { $0.uploads.map(\.bucket) } }

    func upload(_ data: Data, path: String, bucket: ImageBucket, contentType: String) async throws(KodaError) {
        let shouldFail = state.withLock { state -> Bool in
            if state.failuresLeft > 0 {
                state.failuresLeft -= 1
                return true
            }
            state.uploads.append((path, bucket))
            state.objects["\(bucket.rawValue)/\(path)"] = data
            return false
        }
        if shouldFail { throw KodaError(type: .noInternet, reason: "Offline.") }
    }

    func download(path: String, bucket: ImageBucket) async throws(KodaError) -> Data {
        guard let data = state.withLock({ $0.objects["\(bucket.rawValue)/\(path)"] }) else {
            throw KodaError(type: .notFound, reason: "Object not found.")
        }
        return data
    }
}

/// Always online.
struct OnlineReachability: NetworkReachabilityMonitoring {
    func updates() -> AsyncStream<Bool> {
        AsyncStream { $0.yield(true) }
    }
}

enum TestImages {
    /// A PNG of `width` × `height` pixels.
    struct EncodingFailed: Error {}

    static func png(width: Int, height: Int) throws -> Data {
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { throw EncodingFailed() }
        context.setFillColor(CGColor(red: 0.35, green: 0.16, blue: 0.09, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw EncodingFailed() }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw EncodingFailed() }
        return data as Data
    }
}
