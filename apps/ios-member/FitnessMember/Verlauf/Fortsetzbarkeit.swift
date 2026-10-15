import Foundation

/// Wann die Zusammenfassung "Fortsetzen" anbietet und was ein Fehler danach
/// bedeutet (Testnotiz 14.10., 18:45 #3/#4) -- als reine Regeln, damit sie
/// ohne View pruefbar sind.
enum Fortsetzbarkeit {
    /// Die Id des Teils, den der Play-Button fortsetzt, oder nil. Eine
    /// zusammengelegte Karte setzt nur ihren juengsten Teil fort: nur der
    /// wurde zuletzt beendet. `darf` ist `WorkoutSessionStore.kannWiederaufnehmen`.
    static func fortsetzbarerTeil(_ karte: Trainingskarte, darf: (String) -> Bool) -> String? {
        guard let juengster = karte.teile.last, darf(juengster.id) else { return nil }
        return juengster.id
    }

    /// Jeder conflict ("zu spaet", "automatisch beendet") heisst: der Server
    /// oeffnet diese Einheit nie mehr -- die Ablage geht, der Button auch.
    static func folgeNachFehler(_ fehler: APIError) -> (text: String, ablageVerwerfen: Bool) {
        switch fehler {
        case .offline: ("Ohne Verbindung geht Fortsetzen nicht.", false)
        case .conflict(let message): (message, true)
        default: (fehler.servertext, false)
        }
    }
}
