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
    /// Detail einer Muskelgruppe aus dem Uebungsfortschritt (Sicht
    /// "Muskelgruppen").
    case muskelgruppe(MuskelHauptgruppe)
    /// Eine Planeinheit (`PlanEinheitView`) aus "Nächste Einheit" oder dem
    /// gewaehlten Plantag -- im Home-Stack, ohne Tab-Wechsel (E2).
    case einheit(key: String)
}

/// Wohin Home im Plan-Tab springt: die Woche, eine Einheit oder ein Tag
/// ("Im Plan" am gewaehlten Plantag, "Nächste Einheit" als Kurs oder Cardio).
enum PlanSprung: Equatable {
    case woche
    case einheit(key: String)
    /// `startOfDay` des Tages im Studio-Kalender.
    case tag(Date)
}
