import Foundation

/// The platform a recipe video link points to. Only the URL is stored; the platform and the account are derived.
enum RecipeLinkPlatform: String, Sendable, Equatable, CaseIterable {
    case tiktok
    case instagram
    case youtube
    case other

    /// The longest URL the backend accepts (`recipe_links.url`).
    static let maxURLLength = 2048

    /// Finds the first `http(s)` link in `text` (a bare URL, or one pasted with surrounding text such as "Mira esto
    /// https://vm.tiktok.com/ZM123/ 😋") and recognises its platform and account. Known hosts without a scheme
    /// (`tiktok.com/@koda/video/1`) are accepted too. `nil` when there is no valid `http(s)` URL.
    static func detect(url text: String) -> RecipeLinkInfo? {
        guard let url = extractURL(from: text) else { return nil }
        let host = normalizedHost(of: url)
        let components = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }

        if host == "tiktok.com" || host.hasSuffix(".tiktok.com") {
            return RecipeLinkInfo(platform: .tiktok, account: handle(in: components), url: url)
        }
        if host == "instagram.com" || host == "instagr.am" {
            return RecipeLinkInfo(platform: .instagram, account: instagramAccount(in: components), url: url)
        }
        if host == "youtube.com" || host == "youtu.be" || host == "youtube-nocookie.com" {
            return RecipeLinkInfo(platform: .youtube, account: handle(in: components), url: url)
        }
        return RecipeLinkInfo(platform: .other, account: nil, url: url)
    }

    // MARK: - Private Methods

    private static let knownHosts = ["tiktok.com", "vm.tiktok.com", "instagram.com", "youtube.com", "youtu.be"]

    private static func extractURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        let candidate =
            tokens.first { $0.lowercased().contains("http://") || $0.lowercased().contains("https://") }
            .map { token -> String in
                // "(https://…)" or "enlace:https://…": start at the scheme.
                let lowercased = token.lowercased()
                let start = lowercased.range(of: "https://") ?? lowercased.range(of: "http://")
                return start.map { String(token[$0.lowerBound...]) } ?? token
            }
            ?? tokens.first { token in
                let lowercased = token.lowercased()
                return knownHosts.contains { lowercased.hasPrefix($0 + "/") || lowercased.hasPrefix("www." + $0 + "/") }
            }
            .map { "https://" + $0 }
        guard var string = candidate else { return nil }
        // Punctuation glued to the end of a sentence is not part of the link.
        while let last = string.last, ".,;:!?)]}>\"'»".contains(last) {
            string.removeLast()
        }
        guard string.count <= maxURLLength, let url = URL(string: string),
            let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
            let host = url.host(), !host.isEmpty, host.contains(".")
        else { return nil }
        return url
    }

    /// Lowercased host without `www.` or `m.` (`m.youtube.com` → `youtube.com`).
    static func normalizedHost(of url: URL) -> String {
        var host = url.host()?.lowercased() ?? ""
        for prefix in ["www.", "m."] where host.hasPrefix(prefix) {
            host.removeFirst(prefix.count)
        }
        return host
    }

    /// `@user` in the path (`tiktok.com/@user/video/1`, `youtube.com/@user/shorts`).
    private static func handle(in components: [String]) -> String? {
        guard let handle = components.first(where: { $0.hasPrefix("@") && $0.count > 1 }) else { return nil }
        return handle
    }

    /// `instagram.com/<user>/reel/…` or `instagram.com/stories/<user>/…`; `nil` for `/reel/…` and `/p/…`.
    private static func instagramAccount(in components: [String]) -> String? {
        guard let first = components.first else { return nil }
        let reserved: Set<String> = ["p", "reel", "reels", "tv", "explore", "share"]
        if first == "stories" {
            return components.dropFirst().first.map { "@" + $0 }
        }
        return reserved.contains(first.lowercased()) ? nil : "@" + first
    }
}

/// What a recipe link points to.
struct RecipeLinkInfo: Sendable, Equatable {
    let platform: RecipeLinkPlatform
    /// `@user` when the URL carries it.
    let account: String?
    let url: URL

    /// `tiktok.com`, `youtube.com/shorts`: what identifies the link when there is no account.
    var source: String {
        let host = RecipeLinkPlatform.normalizedHost(of: url)
        if platform == .youtube, url.pathComponents.contains("shorts") {
            return host + "/shorts"
        }
        return host
    }
}
