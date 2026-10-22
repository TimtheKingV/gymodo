import Foundation

/// Die Antwort auf "Wie viele Wiederholungen waeren im letzten Satz noch
/// drin gewesen?" (Trainingsplan-Spec Abschnitt 6). Eine Frage je Uebung,
/// nicht je Satz: die Eingabe je Satz ist am 11.09. bewusst gefallen, weil
/// sie jeden Satz langsamer machte.
enum Reserve: Equatable, Hashable {
    /// 0...5; 5 steht fuer "5+". Mehr unterscheidet die Regel nicht.
    case wert(Int)
    /// "Weiss nicht" -- gespeichert als nil, nie als 0.
    case unbekannt

    static let werte = Array(0...5)

    /// Was am Satz landet.
    var rir: Double? {
        switch self {
        case .wert(let zahl): Double(min(max(zahl, 0), 5))
        case .unbekannt: nil
        }
    }
}
