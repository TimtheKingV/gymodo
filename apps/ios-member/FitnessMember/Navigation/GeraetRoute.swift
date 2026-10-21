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
    /// Die Satzseite. `start` kommt aus dem Drawer vor der Uebung (Testnotiz
    /// 11.10., #10) und laesst sie mit dem Countdown beginnen; ohne (Zirkel
    /// ueber die Blockliste) stehen gleich die Raeder.
    /// `zirkel`: der Screen gehoert zu einem laufenden Mini-Zirkel (Spec
    /// 21.10.) -- nach einem gesicherten Satz fuehrt dann die Zirkel-Ebene
    /// weiter, und Startwerte beginnen ohne Countdown.
    case geraet(station: String, exerciseId: String, token: String?, start: Startwerte? = nil,
                zirkel: Bool = false)
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
