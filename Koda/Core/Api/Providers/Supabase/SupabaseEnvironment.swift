import Foundation

/// Supabase configuration of the single `koda` project, read from `Configuration/Info.plist`.
enum SupabaseEnvironment {
    /// Project URL (`SUPABASE_URL`), or `nil` while the placeholder has not been replaced.
    static var projectURL: URL? {
        AppEnvironment.nonEmptyValue(forKey: "SUPABASE_URL").flatMap(validatedURL)
    }

    /// Publishable key (`sb_publishable_…`) from the ignored `Koda.private.xcconfig`.
    static var publishableKey: String? {
        AppEnvironment.nonEmptyValue(forKey: "SUPABASE_PUBLISHABLE_KEY")
    }

    static var isHTTPLoggingEnabled: Bool {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "HTTP_LOGGING_ENABLED") as? String
        return (rawValue as NSString?)?.boolValue ?? false
    }

    static func validatedURL(_ rawValue: String) -> URL? {
        guard let url = URL(string: rawValue), url.scheme == "https" || url.scheme == "http", url.host != nil,
            !rawValue.contains("<")
        else {
            return nil
        }
        return url
    }
}
