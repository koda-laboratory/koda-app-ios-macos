import Foundation

extension ProcessInfo {
    /// `true` while Xcode hosts the app process only to render SwiftUI previews.
    ///
    /// The app launch then skips session bootstrap, push registration and networking so previews start fast
    /// and stay deterministic.
    var isRunningForPreviews: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// `true` while the process hosts the `KodaTests` bundle.
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil
    }

    /// `true` when launch-time work (session restore, push registration, sync) must be skipped.
    var skipsAppBootstrap: Bool {
        isRunningForPreviews || isRunningTests
    }
}
