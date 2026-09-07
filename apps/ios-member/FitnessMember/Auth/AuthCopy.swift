import Foundation

/// Einzige Quelle fuer sicherheitskritische, bewusst neutrale Texte.
/// LoginMailView und MemberRegistrierenView referenzieren
/// unbekanntOderFalsch direkt -- kein Screen kopiert den String-Literal
/// separat (Design-Challenge-Entscheidung #4, spec SS9).
enum AuthCopy {
    static let unbekanntOderFalsch =
        "E-Mail oder Passwort stimmt nicht, oder es gibt kein Konto zu dieser Adresse."
    static let sicherheitshinweisPasswortVergessen =
        "Wenn es zu dieser Adresse ein Konto gibt, ist die Mail unterwegs."
    static let codeUngueltig = "Der Code ist ungültig oder abgelaufen."
    static let passwoerterStimmenNichtUeberein = "Die beiden Passwörter stimmen nicht überein."
    static let aktuellesPasswortFalsch = "Das aktuelle Passwort ist falsch."
}
