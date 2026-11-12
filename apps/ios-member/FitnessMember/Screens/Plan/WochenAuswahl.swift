import Foundation

/// Das Wochenziel, wie "Woche anpassen" (und das Onboarding) es bearbeitet:
/// wie oft Kraft, wie oft Cardio und wie lange -- nicht wann (Spec P2 §4).
/// Reiner Wert, unabhaengig vom Sheet.
struct WochenAuswahl: Equatable {
    static let kraftGrenzen = 1...7
    static let cardioGrenzen = 0...7
    static let minutenGrenzen = 10...90
    static let minutenSchritt = 5

    var kraft: Int
    var cardio: Int
    var cardioMinuten: Int
    var cardioArten: [String]

    /// Klemmt an die Grenzen; Minuten auf den naechsten 5er-Schritt.
    init(ziel: Wochenziel, profil: TrainingsplanProfil?) {
        kraft = Self.klemmen(ziel.kraft, Self.kraftGrenzen)
        cardio = Self.klemmen(ziel.cardio, Self.cardioGrenzen)
        cardioMinuten = Self.minutenGeklemmt(ziel.cardioMinuten)
        cardioArten = profil?.cardioArten ?? []
    }

    static func klemmen(_ wert: Int, _ grenzen: ClosedRange<Int>) -> Int {
        min(max(wert, grenzen.lowerBound), grenzen.upperBound)
    }

    static func minutenGeklemmt(_ minuten: Int) -> Int {
        let gerundet = Int((Double(minuten) / Double(minutenSchritt)).rounded()) * minutenSchritt
        return klemmen(gerundet, minutenGrenzen)
    }

    mutating func cardioArtUmschalten(_ code: String) {
        if let i = cardioArten.firstIndex(of: code) {
            cardioArten.remove(at: i)
        } else {
            cardioArten.append(code)
        }
    }

    /// Das Profil fuer das PUT: nur die drei Zaehler und die Cardio-Arten; die
    /// Tagesfelder bleiben nil (der Server laesst sie unveraendert).
    func profil(aus alt: TrainingsplanProfil) -> TrainingsplanProfil {
        TrainingsplanProfil(
            minutes: alt.minutes, experience: alt.experience, focus: alt.focus,
            cardioArten: cardioArten,
            kraftProWoche: Self.klemmen(kraft, Self.kraftGrenzen),
            cardioProWoche: Self.klemmen(cardio, Self.cardioGrenzen),
            cardioMinuten: Self.minutenGeklemmt(cardioMinuten))
    }
}
