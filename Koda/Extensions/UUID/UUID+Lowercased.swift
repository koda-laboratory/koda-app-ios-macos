import Foundation

extension UUID {
    /// The lowercase form Postgres returns, used as local primary keys.
    var lowercasedString: String {
        uuidString.lowercased()
    }
}
