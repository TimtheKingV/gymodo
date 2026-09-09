import Foundation

/// Ladezustand des Verlaufs. Spiegelt `KurseLadeZustand`, ist aber ein
/// eigener Typ: dort entscheidet der Zustand zusaetzlich darueber, ob
/// eine Belegungszahl ueberhaupt gezeigt werden darf. Hier gibt es
/// nichts, was so schnell unwahr wird.
enum VerlaufLadeZustand: Equatable {
    case bereit
    case laedt
    case geladen
    /// Traegt den tatsaechlichen Fehler: "offline" darf projektweit nie
    /// als "fehlgeschlagen" erscheinen (designsystem.md SS5).
    case fehlgeschlagen(APIError)
}

/// Wie das zustande kam, was der Home-Tab gerade zeigt.
///
/// Bewusst OHNE `veraltet` und ohne Frischegrenze -- das ist der
/// Unterschied zu `KurseHerkunft`, und er ist keine Nachlaessigkeit: eine
/// Belegungszahl veraltet binnen Minuten, ohne dass jemand etwas tut. Ein
/// Verlauf aendert sich ausschliesslich durch das eigene Tun; ein
/// Training von gestern ist morgen noch genau so gewesen. Die
/// Fuenf-Minuten-Grenze der Kurse setzte hier ein Datum ueber etwas, das
/// noch stimmt.
enum VerlaufHerkunft: Equatable {
    case frisch
    case ohneEmpfang
    case serverfehler

    static func bilden(ladeZustand: VerlaufLadeZustand) -> VerlaufHerkunft {
        guard case .fehlgeschlagen(let fehler) = ladeZustand else { return .frisch }
        return fehler == .offline ? .ohneEmpfang : .serverfehler
    }

    var symbol: String? {
        switch self {
        case .frisch: nil
        case .ohneEmpfang: "wifi.slash"
        case .serverfehler: "clock.arrow.circlepath"
        }
    }

    /// `nil`, solange der letzte Abruf durchging -- ein Datum ueber
    /// frischen Zahlen waere Rauschen.
    func satz(stand: Date?) -> String? {
        guard self != .frisch else { return nil }
        return Herkunftssatz.bilden(ohneEmpfang: self == .ohneEmpfang, stand: stand)
    }
}
