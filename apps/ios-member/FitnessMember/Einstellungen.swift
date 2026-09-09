import Foundation

/// Die drei Schalter aus Profil.dc.html an einer Stelle.
///
/// Vorher stand `@AppStorage("rirSichtbar")` mitten in GeraetView. Bei
/// drei Einstellungen, die an je zwei Stellen gelesen werden (Screen und
/// Profil), ist eine verstreute Zeichenkette ein Tippfehler mit stiller
/// Wirkung: der Screen liest dann eine Einstellung, die niemand gesetzt
/// hat.
///
/// Die Lesefunktionen nehmen `UserDefaults` entgegen, damit sie pruefbar
/// bleiben; die Views lesen dieselben Schluessel ueber @AppStorage.
enum Einstellungen {
    /// Woertlich aus Sub-Projekt 2 -- ein anderer Name hiesse, dass jede
    /// Bestandsinstallation ihre Einstellung verliert.
    static let rirSichtbarKey = "rirSichtbar"
    static let resttimerSekundenKey = "resttimerSekunden"
    static let vibrationBeimSichernKey = "vibrationBeimSichern"

    static let resttimerVorgabe = 90
    static let resttimerStufen = [45, 60, 90, 120, 180]

    /// `integer(forKey:)` liefert 0 fuer einen nie gesetzten Schluessel --
    /// 0 Sekunden Pause waere keine Einstellung, sondern ein Fehler.
    static func resttimerSekunden(_ defaults: UserDefaults = .standard) -> Int {
        let gesetzt = defaults.integer(forKey: resttimerSekundenKey)
        return gesetzt > 0 ? gesetzt : resttimerVorgabe
    }

    /// Vorgabe an: die Hauptaktion wird oft mit Blick aufs Geraet statt
    /// aufs Telefon bedient. `bool(forKey:)` liefert false fuer einen nie
    /// gesetzten Schluessel, deshalb die Umkehrung ueber object(forKey:).
    static func vibriertBeimSichern(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: vibrationBeimSichernKey) as? Bool ?? true
    }
}
