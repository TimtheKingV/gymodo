import Foundation
import Testing
@testable import FitnessMember

@Suite("EmailValidator")
struct EmailValidatorTests {
    @Test("akzeptiert eine gueltige Adresse", arguments: ["lena.wagner@example.de", "a@b.co"])
    func acceptsValid(_ email: String) {
        #expect(EmailValidator.isValid(email))
    }

    @Test("weist eine ungueltige Adresse zurueck", arguments: ["", "keine-adresse", "a@b", "@example.de", "a@.de"])
    func rejectsInvalid(_ email: String) {
        #expect(!EmailValidator.isValid(email))
    }
}

@Suite("PasswordPolicy")
struct PasswordPolicyTests {
    @Test("neun Zeichen sind zu kurz")
    func rejectsNineCharacters() {
        #expect(!PasswordPolicy.isValid("123456789"))
    }

    @Test("zehn Zeichen reichen — config.toml minimum_password_length")
    func acceptsTenCharacters() {
        #expect(PasswordPolicy.isValid("1234567890"))
    }
}

@Suite("CodeEntry")
struct CodeEntryTests {
    @Test("filtert Nicht-Ziffern heraus")
    func filtersNonDigits() {
        #expect(CodeEntry(digits: "4a1b9c7").digits == "4197")
    }

    @Test("kappt bei sechs Ziffern")
    func clampsToSixDigits() {
        #expect(CodeEntry(digits: "1234567").digits == "123456")
    }

    @Test("isComplete erst bei genau sechs Ziffern")
    func isCompleteAtSix() {
        #expect(!CodeEntry(digits: "12345").isComplete)
        #expect(CodeEntry(digits: "123456").isComplete)
    }

    @Test("remaining zaehlt bis sechs")
    func remainingCounts() {
        #expect(CodeEntry(digits: "1234").remaining == 2)
    }
}
