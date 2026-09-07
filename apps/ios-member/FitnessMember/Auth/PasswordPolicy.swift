import Foundation

/// Minimum aus supabase/config.toml minimum_password_length (auf 10 erhoeht
/// seit der Passwort-Umstellung, siehe gesamtfahrplan.md Abschnitt "Phase 0").
enum PasswordPolicy {
    static let minimumLength = 10

    static func isValid(_ password: String) -> Bool {
        password.count >= minimumLength
    }
}
