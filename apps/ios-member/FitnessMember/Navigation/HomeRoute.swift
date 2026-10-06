import Foundation

/// Der typisierte Pfad des Home-Tabs -- wie `KursRoute`: beide Ziele sind
/// Pushes und behalten die Tab-Leiste.
enum HomeRoute: Hashable {
    case sessionDetail(id: String)
    case uebungsfortschritt(exerciseId: String)
    /// Die Gewichtskarte auf Home fuehrt hierher (Aufgabe 8); der Screen
    /// selbst ist `GewichtsverlaufView` (Aufgabe 9).
    case gewichtsverlauf
    /// Ein eigener Kurs aus dem Wochenstreifen (Testnotiz 06.10., #1) --
    /// derselbe Screen wie auf der Kurse-Seite.
    case kursDetail(sessionId: String)
}
