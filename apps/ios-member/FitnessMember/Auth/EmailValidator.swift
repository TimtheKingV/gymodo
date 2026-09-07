import Foundation

enum EmailValidator {
    private static let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#

    static func isValid(_ email: String) -> Bool {
        email.range(of: pattern, options: .regularExpression) != nil
    }
}
