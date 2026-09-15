import Foundation

/// Der typisierte Pfad des Home-Tabs -- wie `KursRoute`: beide Ziele sind
/// Pushes und behalten die Tab-Leiste.
enum HomeRoute: Hashable {
    case sessionDetail(id: String)
    case uebungsfortschritt(exerciseId: String)
    /// Die Gewichtskarte auf Home fuehrt hierher (Aufgabe 8); der Screen
    /// selbst kommt erst in Aufgabe 9 (bis dahin `PlaceholderView`).
    case gewichtsverlauf
}
