import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A photo ready to upload: JPEG bytes and their pixel size.
struct TranscodedImage: Sendable, Equatable {
    let data: Data
    let width: Int
    let height: Int
}

/// Re-encodes and downsamples images with ImageIO (the same code on iPhone and Mac; HEIC, JPEG, PNG and WebP in).
protocol ImageTranscoding: Sendable {
    /// JPEG no larger than `maxPixelSize` on its longest side, upright (EXIF orientation applied), without metadata.
    func jpeg(from data: Data, maxPixelSize: Int, quality: Double) -> TranscodedImage?
}

struct ImageIOTranscoder: ImageTranscoding {
    func jpeg(from data: Data, maxPixelSize: Int, quality: Double) -> TranscodedImage? {
        guard let image = ImageDecoding.thumbnail(from: data, maxPixelSize: maxPixelSize) else { return nil }
        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return TranscodedImage(data: output as Data, width: image.width, height: image.height)
    }
}

/// Decoding for display: a downsampled `CGImage` keeps memory low in grids and strips.
enum ImageDecoding {
    static func thumbnail(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
