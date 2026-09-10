import Foundation

/// Der typisierte Pfad des Kurse-Tabs.
///
/// Seit die eigenen Anmeldungen als Band auf dem Wochenplan stehen
/// (`KurseBandView`), gibt es nur noch ein Ziel. `.meine` ist damit
/// weggefallen -- und mit ihm der Textknopf oben rechts, der der einzige
/// Weg dorthin war.
///
/// Ein `enum` mit einem Fall statt eines nackten `String`-Pfads: der
/// naechste Push (etwa eine Kursbeschreibung) soll wieder typisiert
/// danebenstehen koennen, ohne dass der Pfad umgebaut werden muss.
///
/// `KursDetailView(sessionId:)` hat bewusst keinen eigenen Zurueck-Knopf --
/// die Signatur gibt keinen Rueckweg her, und der Screen verlaesst sich
/// vollstaendig auf den System-Zurueckpfeil eines `NavigationStack`. Wird er
/// nicht als Push in einem solchen Stack geoeffnet, sitzt das Mitglied fest.
enum KursRoute: Hashable {
    case detail(sessionId: String)
}
