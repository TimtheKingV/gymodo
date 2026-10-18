import Foundation

/// Parameter der Satzende-Auswertung (`Satztakt`) je Befestigungsart. Alle
/// Zeiten in Sekunden, damit eine andere Abtastrate nichts verschiebt.
/// Kurzhantel traegt die Werte, die an den Aufnahmen vom 16.10. abgestimmt
/// wurden und nicht ohne Gegenprobe veraendert werden duerfen.
public struct TaktProfil: Sendable, Equatable {
    /// Kuerzester und laengster Takt. Laengere Takte waren an den
    /// Aufnahmen vom 16.10. Verdopplungen (Druecken: 3,1 bis 3,4 s statt 1,6 s).
    public let taktMin: TimeInterval
    public let taktMax: TimeInterval
    /// Das Signal wird auf dieses Vielfache des typischen Sekunden-Effektivwerts
    /// gekappt: Aufheben und Ablegen sind sonst staerker als die Wiederholungen.
    public let kappFaktor: Double
    /// Ein Oberton ist kuerzer als der Takt: der kleinste Kandidat mit
    /// mindestens diesem Anteil der besten Korrelation gewinnt.
    public let kandidatAnteil: Double
    /// Mindestgleichheit zweier aufeinanderfolgender Wiederholungen.
    public let gleichheitMin: Double
    /// Abstand zur naechsten Wiederholung in Takten: das Tempo schwankt im Satz.
    public let abstandMin: Double
    public let abstandMax: Double
    /// Kuerzere Saetze werden nicht ausgewertet.
    public let mindestDauer: TimeInterval

    public static let kurzhantel = TaktProfil(
        taktMin: 1.2, taktMax: 3.0, kappFaktor: 1.5, kandidatAnteil: 0.85,
        gleichheitMin: 0.9, abstandMin: 0.75, abstandMax: 1.3, mindestDauer: 5.0)

    /// nil: fuer diese Art zaehlt am Satzende weiter die Live-Zahl.
    public static func fuer(_ art: Befestigungsart) -> TaktProfil? {
        switch art {
        case .kurzhantel, .stapel, .langhantel: .kurzhantel
        case .hebelarm, .kabelgriff, .koerper: nil
        }
    }
}
