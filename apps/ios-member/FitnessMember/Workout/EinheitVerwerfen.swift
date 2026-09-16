import Foundation

/// Wie "Verwerfen" auf dem Abschluss-Screen die Einheit loswird
/// (Sammelstelle Punkt 19).
enum EinheitVerwerfen {
    enum Weg: Equatable {
        /// Kein Satz hat den Server erreicht -- er kennt die Einheit nicht
        /// (recordSet legt sie erst mit dem ersten Satz an). Die
        /// Warteschlange leeren genuegt, und das geht auch im Keller.
        case nurLokal
        /// Mindestens ein Satz liegt beim Server: erst DELETE, DANN die
        /// Warteschlange. Andersherum staende nach einem Fehlschlag eine
        /// halbe Einheit beim Server, die niemand mehr loeschen kann.
        case ueberDenServer
    }

    static func weg(offeneSchreibvorgaenge: Int, satzAnzahl: Int) -> Weg {
        offeneSchreibvorgaenge >= satzAnzahl ? .nurLokal : .ueberDenServer
    }
}
