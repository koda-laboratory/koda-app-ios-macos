// MARK: - Form State

protocol FormState: Sendable, Equatable { var isValid: Bool { get } }
