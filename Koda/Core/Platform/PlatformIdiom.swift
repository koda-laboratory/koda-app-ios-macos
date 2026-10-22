import Foundation

/// The two Koda platforms, for the few layout decisions SwiftUI cannot adapt on its own (the floating "+"
/// on iPhone versus a toolbar button on the Mac).
enum PlatformIdiom: Sendable {
    case phone
    case mac

    static var current: PlatformIdiom {
        #if os(macOS)
            .mac
        #else
            .phone
        #endif
    }
}
