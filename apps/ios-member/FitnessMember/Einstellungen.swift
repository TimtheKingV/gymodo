import Foundation

/// Die Schalter aus Profil.dc.html an einer Stelle.
///
/// Vorher standen sie als nackte `@AppStorage("...")`-Zeichenketten mitten
/// in den Screens. Bei Einstellungen, die an je zwei Stellen gelesen werden
/// (Screen und Profil), ist eine verstreute Zeichenkette ein Tippfehler mit
/// stiller Wirkung: der Screen liest dann eine Einstellung, die niemand
/// gesetzt hat.
///
/// Die Lesefunktionen nehmen `UserDefaults` entgegen, damit sie pruefbar
/// bleiben; die Views lesen dieselben Schluessel ueber @AppStorage.
enum Einstellungen {
    /// Woertlich aus Sub-Projekt 2 -- ein anderer Name hiesse, dass jede
    /// Bestandsinstallation ihre Einstellung verliert.
    static let resttimerSekundenKey = "resttimerSekunden"
    static let vibrationBeimSichernKey = "vibrationBeimSichern"

    static let satzZielKey = "satzZiel"

    static let resttimerVorgabe = 90
    static let resttimerStufen = [45, 60, 90, 120, 180]

    /// Wie viele Saetze an einem Geraet geplant sind. Es gibt (noch) keinen
    /// Trainingsplan in den Daten -- `exercises` kennt nur einen
    /// Wiederholungskorridor, keine Satzzahl. Bis dahin ist das hier die
    /// ehrlichste Stelle fuer die Zahl: eine Vorgabe, die das Mitglied
    /// selbst verschieben kann, statt einer erfundenen Zahl vom Server.
    static let satzZielVorgabe = 3
    static let satzZielStufen = [2, 3, 4, 5]

    /// `integer(forKey:)` liefert 0 fuer einen nie gesetzten Schluessel --
    /// 0 Sekunden Pause waere keine Einstellung, sondern ein Fehler.
    static func resttimerSekunden(_ defaults: UserDefaults = .standard) -> Int {
        let gesetzt = defaults.integer(forKey: resttimerSekundenKey)
        return gesetzt > 0 ? gesetzt : resttimerVorgabe
    }

    /// Gilt je Geraet UND Uebung -- also je Block, den WorkoutSessionStore
    /// zaehlt, nicht je Einheit. `integer(forKey:)` liefert 0 fuer einen nie
    /// gesetzten Schluessel; ein Satzziel von 0 waere keine Einstellung,
    /// sondern ein Geraet, das man nie betreten darf.
    static func satzZiel(_ defaults: UserDefaults = .standard) -> Int {
        let gesetzt = defaults.integer(forKey: satzZielKey)
        return gesetzt > 0 ? gesetzt : satzZielVorgabe
    }

    /// Vorgabe an: die Hauptaktion wird oft mit Blick aufs Geraet statt
    /// aufs Telefon bedient. `bool(forKey:)` liefert false fuer einen nie
    /// gesetzten Schluessel, deshalb die Umkehrung ueber object(forKey:).
    static func vibriertBeimSichern(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: vibrationBeimSichernKey) as? Bool ?? true
    }
}
