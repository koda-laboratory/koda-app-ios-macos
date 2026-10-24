import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// An image the user picked (Photos), dropped (drag and drop) or imported, as raw bytes for the photo pipeline.
struct PickedImage: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { PickedImage(data: $0) }
        FileRepresentation(importedContentType: .image) { received in
            PickedImage(data: try Data(contentsOf: received.file))
        }
    }
}
