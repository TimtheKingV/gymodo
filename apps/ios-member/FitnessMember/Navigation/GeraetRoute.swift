import Foundation

/// Der typisierte Pfad des Training-Tabs.
///
/// Der Geraete-Screen ist kein Tab -- er wird als Push INNERHALB von
/// Training geoeffnet und behaelt die Tab-Leiste (designsystem.md SS11).
enum GeraetRoute: Hashable {
    /// Die Geraeteliste -- ein Push wie die anderen Ziele, damit die
    /// Tab-Leiste stehen bleibt (designsystem.md SS11).
    case auswahl
    case erkannt(machineId: String, token: String?)
    case geraet(machineId: String, exerciseId: String, token: String?)
    /// Der Abschluss-Screen (Aufgabe 6) braucht die Zahlen der beendeten
    /// Einheit -- sessionId dient nur der Nachverfolgung, die Anzeige
    /// selbst kommt vollstaendig aus zusammenfassung.
    case abschluss(sessionId: UUID, zusammenfassung: Trainingszusammenfassung)
}
