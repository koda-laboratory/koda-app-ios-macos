import Foundation

// MARK: - Localizable

extension String {
    var localized: String {
        Bundle.main.localizedString(forKey: self, value: self, table: nil)
    }

    func localized(_ arguments: CVarArg...) -> String {
        String(format: localized, arguments: arguments)
    }
}
