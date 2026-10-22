import Foundation

/// Profile previews over the seeded in-memory database (sync and logout are never triggered).
@MainActor
enum ProfilePreviewFactory {
    static func makeProfileViewModel(container: DependencyContainer = PreviewContainer.populated) -> ProfileViewModel {
        Assembly.makeProfileViewModel(container: container)
    }
}
