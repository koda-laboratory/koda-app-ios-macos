/// Email and password of the login screen.
struct LoginFormState: FormState {
    var email = ""
    var password = ""

    var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isEmailValid: Bool {
        let parts = normalizedEmail.split(separator: "@")
        return parts.count == 2 && parts[1].contains(".")
    }

    var isValid: Bool {
        isEmailValid && !password.isEmpty
    }
}
