import Foundation

/// Der typisierte Pfad des Kurse-Tabs.
///
/// `KursDetailView` und `KurseMeineView` sind keine Tabs -- sie werden als
/// Push INNERHALB von Kurse geoeffnet und behalten die Tab-Leiste
/// (designsystem.md SS11), genau wie `GeraetRoute` es fuer den
/// Training-Tab tut.
///
/// `KursDetailView(sessionId:)` hat bewusst keinen eigenen Zurueck-Knopf --
/// die Signatur gibt keinen Rueckweg her, und der Screen verlaesst sich
/// vollstaendig auf den System-Zurueckpfeil eines `NavigationStack`. Wird er
/// nicht als Push in einem solchen Stack geoeffnet, sitzt das Mitglied fest.
enum KursRoute: Hashable {
    case detail(sessionId: String)
    case meine
}
