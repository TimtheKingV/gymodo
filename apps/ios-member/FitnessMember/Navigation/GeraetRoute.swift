import Foundation

/// Der typisierte Pfad des Training-Tabs.
///
/// Der Geraete-Screen ist kein Tab -- er wird als Push INNERHALB von
/// Training geoeffnet und behaelt die Tab-Leiste (designsystem.md SS11).
enum GeraetRoute: Hashable {
    // Die Geraeteliste ist seit der Testnotiz 06.10. (#2) die Wurzel des
    // Tabs selbst und kein Ziel mehr ("case auswahl" ist entfallen).
    //
    // `station` ist der Stationsschluessel ("geraet:<id>" | "typ:<id>"),
    // nicht die Station selbst: die Route bleibt so klein und Hashable, und
    // ein Typ bekommt seinen Ort beim Aufloesen aus dem aktuellen Ort --
    // eine offene Einheit erzwingt ueber Ortswechsel ohnehin denselben.
    case erkannt(station: String, token: String?)
    /// Die Liste einer Kachel mit mehreren Geraeten (Testnotiz 12.10., #3,
    /// #4) -- Freihantel, Geraete, Cardio. Eine Kachel mit einem Geraet
    /// fuehrt gleich zu `.erkannt`.
    case kategorie(Geraetegruppe)
    /// Die Auswahl nach dem Tipp auf eine Planzeile: nur Stationen, die diese
    /// Uebung anbieten (Spec 5, `PlanStart`).
    case planUebung(exerciseId: String)
    /// "Andere Übung wählen" zu einer Planposition: die normale Auswahl mit dem
    /// Kopf `PlanErsatzKopf`. Die Wahl fuehrt zurueck zur Wurzel und in die
    /// Grund-Frage; der Auftrag liegt an der Wurzel (`planErsatzAuftrag`).
    case planErsatz(positionKey: String)
    /// Die Satzseite. `start` kommt aus dem Drawer vor der Uebung (Testnotiz
    /// 11.10., #10) und laesst sie mit dem Countdown beginnen; ohne (Zirkel
    /// ueber die Blockliste) stehen gleich die Raeder.
    /// `zirkel`: der Screen gehoert zu einem laufenden Mini-Zirkel (Spec
    /// 21.10.) -- nach einem gesicherten Satz fuehrt dann die Zirkel-Ebene
    /// weiter, und Startwerte beginnen ohne Countdown. Der Wert ist der Slot
    /// (Zirkel.schritt beim Oeffnen), nicht nur ein Schalter: dieselbe
    /// Uebung kommt in jeder Runde wieder, und ohne eigene Identitaet je
    /// Slot behandelte der NavigationStack [A, Pause] -> [A] als Pop und
    /// holte den alten, schon gesperrten Screen zurueck (Finding C-1).
    case geraet(station: String, exerciseId: String, token: String?, start: Startwerte? = nil,
                zirkel: Int? = nil)
    /// Die Pause zwischen zwei Zirkel-Uebungen. Traegt keine Daten: Zirkel
    /// und Pause liegen im ZirkelAblauf an der Wurzel.
    case zirkelPause
    /// Nach dem letzten Slot (oder "Zirkel beenden"): alle Uebungen und Runden.
    case zirkelUebersicht
    /// Der Abschluss-Screen (Aufgabe 6) braucht die Zahlen der beendeten
    /// Einheit -- sessionId dient nur der Nachverfolgung, die Anzeige
    /// selbst kommt vollstaendig aus zusammenfassung.
    case abschluss(sessionId: UUID, zusammenfassung: Trainingszusammenfassung)
}
