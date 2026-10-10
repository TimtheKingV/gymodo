import Foundation

/// Parameter je Befestigungsart (Spec B 5.2, 5.3). Alle Zahlen sind
/// Startwerte und werden an den Aufnahmen abgestimmt; jede Aenderung
/// erhoeht `version` und setzt `eingefrorenAm` neu, damit das Torset nur
/// Saetze zaehlt, die der Zaehler vorher nicht gesehen hat (Spec B 5.5).
public struct ZaehlerProfil: Equatable, Sendable {
    public enum Signal: Equatable, Sendable {
        /// Drehrate um die Achse mit der groessten Streuung: Hantel, Hebel, Kabelgriff.
        case drehrate
        /// Geschwindigkeit entlang der Schwerkraft: Stapel, Koerper.
        case geschwindigkeitVertikal
    }

    public let art: Befestigungsart
    public let version: Int
    public let eingefrorenAm: Date?
    public let signal: Signal
    /// Grenzfrequenz des Tiefpasses in Hz. Eine Wiederholung dauert ueber
    /// eine Sekunde; alles ueber 3 Hz ist Zittern oder Klappern.
    public let tiefpassHz: Double
    /// Halbwellen-Schwelle vor der ersten Wiederholung (Grad/s bzw. m/s).
    public let startSchwelle: Double
    /// Danach: Schwelle = max(startSchwelle, schwellenAnteil * Ausschlag der ersten).
    public let schwellenAnteil: Double
    public let mindestDauer: TimeInterval
    public let hoechstDauer: TimeInterval
    /// Ab der dritten Wiederholung: unter diesem Anteil am Median-Ausschlag ist sie schwach.
    public let schwachAnteil: Double
    /// Ab der dritten Wiederholung: erlaubter Faktor der Dauer um den Median.
    public let taktBand: Double
    /// Messwertabstand, ab dem eine Luecke vorliegt (auch App im Hintergrund, Spec A 11.1).
    public let lueckeAb: TimeInterval
    /// Ruhe: Drehrate unter diesem Betrag (Grad/s) ...
    public let ruheDrehrate: Double
    /// ... und Betrag der Beschleunigung so nah an 1 g.
    public let ruheBeschleunigung: Double
    /// Bewegungszeit, aus der die Drehachse bestimmt wird.
    public let achsenFenster: TimeInterval
    /// Zeitkonstante der leckenden Integration; haelt die Drift der
    /// Geschwindigkeit klein, ohne eine Wiederholung zu verschlucken.
    public let leckZeit: TimeInterval

    public var algo: String { "\(art.rawValue)/\(version)" }

    public static func fuer(_ art: Befestigungsart) -> ZaehlerProfil {
        switch art {
        case .langhantel, .kurzhantel, .hebelarm, .kabelgriff:
            ZaehlerProfil(art: art, version: 1, eingefrorenAm: nil, signal: .drehrate,
                          tiefpassHz: 3, startSchwelle: 30, schwellenAnteil: 0.35,
                          mindestDauer: 0.6, hoechstDauer: 10, schwachAnteil: 0.4, taktBand: 2.5,
                          lueckeAb: 0.5, ruheDrehrate: 10, ruheBeschleunigung: 0.05,
                          achsenFenster: 1.0, leckZeit: 1.0)
        case .stapel, .koerper:
            ZaehlerProfil(art: art, version: 1, eingefrorenAm: nil, signal: .geschwindigkeitVertikal,
                          tiefpassHz: 3, startSchwelle: 0.12, schwellenAnteil: 0.35,
                          mindestDauer: 0.6, hoechstDauer: 10, schwachAnteil: 0.4, taktBand: 2.5,
                          lueckeAb: 0.5, ruheDrehrate: 10, ruheBeschleunigung: 0.05,
                          achsenFenster: 1.0, leckZeit: 1.0)
        }
    }
}
