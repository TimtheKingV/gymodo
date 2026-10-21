import Foundation
import Observation

/// Die Ablaufebene ueber dem Geraete-Screen (Spec Mini-Zirkel 21.10.): sie
/// haelt den laufenden Zirkel und die Pause zwischen zwei Uebungen. Lebt an
/// der Wurzel des Training-Tabs, weil jede Uebung ihren eigenen
/// Geraete-Screen mit eigenem Modell bekommt -- der Zirkel muss den Wechsel
/// ueberleben.
///
/// Die Pause ist ein Resttimer mit festem Endzeitpunkt, kein Zaehler: geht
/// die App in den Hintergrund, laeuft sie gegen die Uhr weiter, und beim
/// Zurueckkommen stimmt die Restzeit ohne eigenes Nachrechnen.
@MainActor
@Observable
final class ZirkelAblauf {
    private(set) var zirkel: Zirkel?
    private(set) var pause: Resttimer?
    /// Von wann bis wann die zuletzt geschaffte Runde lief -- fuer die
    /// Zusammenfassung in der Rundenpause, die nur deren Saetze zeigen darf.
    /// Ein Zeitfenster statt einer Liste uebersprungener Slots: die Saetze
    /// stehen ohnehin mit performedAt in der Einheit, und was in diesem
    /// Fenster nicht gesichert wurde, wurde uebersprungen. Der Zirkel selbst
    /// bleibt davon unberuehrt (die Uebersicht in Task 8 zeigt alle Runden).
    private(set) var geschaffteRunde: DateInterval?
    /// Beginn der laufenden Runde.
    private var rundenbeginn: Date?

    /// `rundeBegann`: wann Runde 1 anfing, falls frueher als jetzt -- beim
    /// Zirkel aus einem Einzelsatz (Task 7) liegt dessen Satz vor dem Start.
    func starten(_ zirkel: Zirkel, jetzt: Date = Date(), rundeBegann: Date? = nil) {
        self.zirkel = zirkel
        pause = nil
        geschaffteRunde = nil
        rundenbeginn = rundeBegann ?? jetzt
    }

    /// Nach jedem gesicherten Satz einer Zirkel-Uebung: ein Slot weiter, dann
    /// die passende Pause -- Uebungspause oder Rundenpause, je nachdem, was
    /// der Zirkel als Naechstes vorhat. Nach dem letzten Slot keine Pause:
    /// dann kommt die Uebersicht, und eine Pause davor waere nur Wartezeit.
    func satzGesichert(jetzt: Date = Date()) {
        weiterruecken(jetzt: jetzt) { $0.weiter() }
    }

    /// Wie ein Satz, nur ohne Satz: der Slot gilt als erledigt.
    func ueberspringen(jetzt: Date = Date()) {
        weiterruecken(jetzt: jetzt) { $0.ueberspringen() }
    }

    /// "+30 s" -- nur auf eine laufende Pause, ohne Pause entsteht keine.
    func pauseVerlaengern() {
        pause = pause?.verlaengert()
    }

    /// Beim Wechsel zur naechsten Uebung: die Pause ist vorbei, auch wenn
    /// ihre Uhr noch liefe ("Weiter" vor dem Ablauf). Wer fragt, ob gerade
    /// eine Pause laeuft, bekommt danach nil.
    func pauseVerlassen() {
        pause = nil
    }

    /// Haengt eine Uebung an, solange Runde 1 gerade komplett ist. Die
    /// laufende Pause bleibt unberuehrt: waehrend das Mitglied waehlt, soll
    /// die Uhr nicht neu anfangen.
    @discardableResult
    func erweitern(um uebung: ZirkelUebung) -> Bool {
        zirkel?.erweitern(um: uebung) ?? false
    }

    /// Gesicherte Saetze stehen in der Einheit, nicht hier -- Beenden
    /// verliert deshalb nichts.
    func beenden() {
        zirkel = nil
        pause = nil
        geschaffteRunde = nil
        rundenbeginn = nil
    }

    private func weiterruecken(jetzt: Date, _ schritt: (inout Zirkel) -> Void) {
        guard var zirkel else { return }
        schritt(&zirkel)
        self.zirkel = zirkel
        // Dieser Slot schloss eine Runde: ihr Fenster festhalten, die
        // naechste beginnt jetzt.
        if zirkel.schritt % zirkel.uebungen.count == 0, let rundenbeginn {
            geschaffteRunde = DateInterval(start: rundenbeginn, end: max(jetzt, rundenbeginn))
            self.rundenbeginn = jetzt
        }
        pause = zirkel.istFertig
            ? nil
            : Resttimer(start: jetzt, dauer: TimeInterval(zirkel.pausenSekunden))
    }
}

/// Der Pfad beim Wechsel zur naechsten Zirkel-Uebung, als reine Rechnung,
/// damit die Regel ohne NavigationStack pruefbar ist.
enum ZirkelPfad {
    /// Ersetzt Pause UND alten Geraete-Screen durch die naechste Uebung:
    /// sonst wuechse der Stapel mit jedem Satz, und "Zurueck" fuehrte durch
    /// alle Uebungen der Runde.
    ///
    /// nil, wenn der Pfad nicht (mehr) auf der Pause steht. Das ist die
    /// Sperre gegen doppeltes Navigieren: laeuft die Pause ab, waehrend
    /// "Weiter" gerade gedrueckt wurde, findet der zweite Aufruf schon die
    /// neue Uebung oben und tut nichts.
    static func ausPause(_ pfad: [GeraetRoute], zu ziel: GeraetRoute) -> [GeraetRoute]? {
        guard pfad.last == .zirkelPause else { return nil }
        var neu = pfad.dropLast()
        if case .geraet = neu.last { neu = neu.dropLast() }
        return Array(neu) + [ziel]
    }

    /// Nach "Überspringen" in der Pause: gleich weiter zur naechsten Uebung
    /// (bzw. zur Uebersicht, wenn nichts mehr kommt) -- ausser der
    /// uebersprungene Slot schloss die Runde. Dann steht jetzt die
    /// Rundenpause an, und die gehoert gezeigt statt uebergangen.
    static func nachUeberspringenWeiter(_ zirkel: Zirkel) -> Bool {
        zirkel.istFertig || !zirkel.naechsterSchrittIstRundenwechsel
    }
}
