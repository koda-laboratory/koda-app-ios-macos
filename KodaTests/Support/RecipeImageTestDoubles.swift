import CoreGraphics
import Foundation
import ImageIO
import Synchronization
import UniformTypeIdentifiers

@testable import Koda

/// Image files in memory, by Storage path.
final class InMemoryRecipeImageFiles: RecipeImageFileDataSource, Sendable {
    private let files = Mutex<[String: Data]>([:])

    var paths: [String] { files.withLock { Array($0.keys).sorted() } }

    func data(at path: String) -> Data? { files.withLock { $0[path] } }

    func fileURL(at path: String) -> URL? {
        data(at: path) == nil ? nil : URL(filePath: "/tmp/koda-tests/\(path)")
    }

    func write(_ data: Data, at path: String) throws(KodaError) { files.withLock { $0[path] = data } }

    func remove(at path: String) { _ = files.withLock { $0.removeValue(forKey: path) } }

    func removeAll() { files.withLock { $0.removeAll() } }
}

/// Storage that records uploads and can fail a number of times first.
final class FakeRecipeImageRemote: RecipeImageRemoteDataSource, Sendable {
    private let state = Mutex<(uploads: [String], failuresLeft: Int, objects: [String: Data])>(([], 0, [:]))

    init(failures: Int = 0, objects: [String: Data] = [:]) {
        state.withLock {
            $0.failuresLeft = failures
            $0.objects = objects
        }
    }

    var uploads: [String] { state.withLock { $0.uploads } }

    func upload(_ data: Data, path: String, contentType: String) async throws(KodaError) {
        let shouldFail = state.withLock { state -> Bool in
            if state.failuresLeft > 0 {
                state.failuresLeft -= 1
                return true
            }
            state.uploads.append(path)
            state.objects[path] = data
            return false
        }
        if shouldFail { throw KodaError(type: .noInternet, reason: "Offline.") }
    }

    func download(path: String) async throws(KodaError) -> Data {
        guard let data = state.withLock({ $0.objects[path] }) else {
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
