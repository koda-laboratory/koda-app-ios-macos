#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

/// The general pasteboard. Read only on a user action ("Pegar"): iPhone asks for permission on every read.
enum PlatformPasteboard {
    static func string() -> String? {
        #if os(iOS)
            UIPasteboard.general.string
        #elseif os(macOS)
            NSPasteboard.general.string(forType: .string)
        #else
            nil
        #endif
    }
}
