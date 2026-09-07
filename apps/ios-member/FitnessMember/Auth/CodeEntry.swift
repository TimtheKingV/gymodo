import Foundation

/// Eingabezustand fuer den sechsstelligen Bestaetigungs-/Reset-Code.
/// Wiederverwendet von LoginCodeView (Aufgabe 14) und MemberPasswortView
/// (Aufgabe 16).
struct CodeEntry: Equatable {
    static let length = 6

    private(set) var digits: String

    init(digits: String = "") {
        self.digits = String(digits.filter(\.isNumber).prefix(Self.length))
    }

    var isComplete: Bool { digits.count == Self.length }
    var remaining: Int { Self.length - digits.count }
}
