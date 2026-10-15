import Foundation

/// Parameter je Befestigungsart (Spec B 5.2, 5.3). Alle Zahlen sind
/// Startwerte und werden an den Aufnahmen abgestimmt; jede Aenderung
/// erhoeht `version` und setzt `eingefrorenAm` neu, damit das Torset nur
/// Saetze zaehlt, die der Zaehler vorher nicht gesehen hat (Spec B 5.5).
public struct ZaehlerProfil: Equatable, Sendable {
    public enum Signal: Equatable, Sendable {
        /// Drehrate um die Achse mit der groessten Streuung: Hantel, Hebel, Kabelgriff.
        case drehrate
        /// Geschwindigkeit entlang der Schwerkraft: Koerper.
        case geschwindigkeitVertikal
        /// Geschwindigkeit aus dem Betrag der Beschleunigung minus 1 g: Stapel.
        /// Der Betrag haengt nicht von der Lage ab; eine Verkippung in der
        /// Bewegung, in der die Schwerkraft nicht nachgefuehrt wird, erzeugt
        /// so keinen Versatz. Der Stapel faehrt senkrecht, quer kommt nichts
        /// dazu. Setzt einen kalibrierten Betrag voraus: am 14.10. lag er in
        /// Ruhe bei 0,997 g, das sind 0,03 m/s Versatz bei 0,12 Startschwelle.
        case geschwindigkeitBetrag
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
    ///
    /// Verglichen wird der absolute Betrag. Das setzt einen Gyro-Gleichanteil
    /// deutlich unter diesem Wert voraus: der werkskalibrierte Sensor zeigt in
    /// Ruhe rund 0,1 Grad/s (Spec A 4), die Tests decken bis 9 Grad/s ab.
    /// Liegt der Gleichanteil darueber, gilt kein Messwert als ruhig: die
    /// Ruhe-Grundlinie wird nie gesetzt (Beginn der ersten Wiederholung
    /// rutscht in den Vorlauf), und ein kurzer Stoss im Vorlauf kann die
    /// Drehachse festlegen (Satz bleibt bei 0). Bewusst nicht abgefangen,
    /// weil das ausserhalb der echten Eingaben liegt.
    public let ruheDrehrate: Double
    /// ... und Betrag der Beschleunigung so nah an 1 g.
    public let ruheBeschleunigung: Double
    /// Bewegungszeit, aus der die Drehachse bestimmt wird.
    public let achsenFenster: TimeInterval
    /// Zeitkonstante der leckenden Integration; haelt die Drift der
    /// Geschwindigkeit klein, ohne eine Wiederholung zu verschlucken.
    public let leckZeit: TimeInterval
    /// Hoechste Drehung in Grad zwischen Beginn und Ende einer Wiederholung,
    /// aus der Drehrate aufintegriert; nil = keine Pruefung. Eine
    /// Wiederholung endet in der Lage, in der sie begann. Aufnehmen,
    /// Ablegen und Einhaengen enden woanders: am 15.10. drehten sie die
    /// Kurzhantel um 85 bis 156 Grad, echte Wiederholungen hoechstens 54.
    public let lageHoechstens: Double?
    /// Nur Drehrate: die Achse nicht aus der ersten Bewegung waehlen,
    /// sondern aus der ersten Wiederholung, die die Lagepruefung besteht.
    /// Bis dahin laufen alle drei Achsen nebeneinander. Am 15.10. legte das
    /// Aufnehmen sonst in vier von neun Saetzen die falsche Achse fest.
    public let achseAusErsterWiederholung: Bool
    /// Vor der ersten Wiederholung: ein Kandidat mit einem Stoss ueber
    /// diesem Betrag (g) ist Aufnehmen, keine Wiederholung; nil = aus.
    public let stossAb: Double?

    public var algo: String { "\(art.rawValue)/\(version)" }

    public static func fuer(_ art: Befestigungsart) -> ZaehlerProfil {
        switch art {
        case .kurzhantel:
            // Version 2 (15.10.): Lagepruefung, Achse aus der ersten
            // Wiederholung, Stoss vor dem Satz, Mindestdauer 1 s (Spec B 5.3:
            // eine Wiederholung dauert ueber eine Sekunde; kuerzere Schwuenge
            // kamen am 15.10. nur beim Aufnehmen und Ablegen vor).
            ZaehlerProfil(art: art, version: 2, eingefrorenAm: nil, signal: .drehrate,
                          tiefpassHz: 3, startSchwelle: 30, schwellenAnteil: 0.35,
                          mindestDauer: 1.0, hoechstDauer: 10, schwachAnteil: 0.4, taktBand: 2.5,
                          lueckeAb: 0.5, ruheDrehrate: 10, ruheBeschleunigung: 0.05,
                          achsenFenster: 1.0, leckZeit: 1.0,
                          lageHoechstens: 80, achseAusErsterWiederholung: true, stossAb: 3)
        case .langhantel:
            // Version 2 (15.10.): die Stange dreht bei der Kniebeuge kaum
            // (30 bis 50 Grad/s), darum wie der Stapel ueber den Betrag. Das
            // Einhaengen am Satzende drehte sie um 81 und 178 Grad und zaehlte
            // sonst als Wiederholung mit.
            ZaehlerProfil(art: art, version: 2, eingefrorenAm: nil, signal: .geschwindigkeitBetrag,
                          tiefpassHz: 3, startSchwelle: 0.12, schwellenAnteil: 0.35,
                          mindestDauer: 0.6, hoechstDauer: 10, schwachAnteil: 0.4, taktBand: 2.5,
                          lueckeAb: 0.5, ruheDrehrate: 10, ruheBeschleunigung: 0.05,
                          achsenFenster: 1.0, leckZeit: 1.0,
                          lageHoechstens: 45, achseAusErsterWiederholung: false, stossAb: nil)
        case .hebelarm, .kabelgriff:
            ZaehlerProfil(art: art, version: 1, eingefrorenAm: nil, signal: .drehrate,
                          tiefpassHz: 3, startSchwelle: 30, schwellenAnteil: 0.35,
                          mindestDauer: 0.6, hoechstDauer: 10, schwachAnteil: 0.4, taktBand: 2.5,
                          lueckeAb: 0.5, ruheDrehrate: 10, ruheBeschleunigung: 0.05,
                          achsenFenster: 1.0, leckZeit: 1.0,
                          lageHoechstens: nil, achseAusErsterWiederholung: false, stossAb: nil)
        case .stapel:
            // Version 2 (14.10.): Betrag statt Projektion, siehe Signal.
            ZaehlerProfil(art: art, version: 2, eingefrorenAm: nil, signal: .geschwindigkeitBetrag,
                          tiefpassHz: 3, startSchwelle: 0.12, schwellenAnteil: 0.35,
                          mindestDauer: 0.6, hoechstDauer: 10, schwachAnteil: 0.4, taktBand: 2.5,
                          lueckeAb: 0.5, ruheDrehrate: 10, ruheBeschleunigung: 0.05,
                          achsenFenster: 1.0, leckZeit: 1.0,
                          lageHoechstens: nil, achseAusErsterWiederholung: false, stossAb: nil)
        case .koerper:
            ZaehlerProfil(art: art, version: 1, eingefrorenAm: nil, signal: .geschwindigkeitVertikal,
                          tiefpassHz: 3, startSchwelle: 0.12, schwellenAnteil: 0.35,
                          mindestDauer: 0.6, hoechstDauer: 10, schwachAnteil: 0.4, taktBand: 2.5,
                          lueckeAb: 0.5, ruheDrehrate: 10, ruheBeschleunigung: 0.05,
                          achsenFenster: 1.0, leckZeit: 1.0,
                          lageHoechstens: nil, achseAusErsterWiederholung: false, stossAb: nil)
        }
    }
}
