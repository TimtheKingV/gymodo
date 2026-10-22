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
    /// Beginn des ganzen Zirkels -- die Uebersicht zaehlt nur Saetze ab
    /// hier, aeltere Saetze im selben Block stammen aus einer Einzeluebung.
    private var begann: Date?

    /// Was die Zirkel-Uebersicht braucht, als Wert. "Zirkel beenden" ruft
    /// beenden() und setzt damit `zirkel` auf nil, die Uebersicht kommt aber
    /// erst danach -- sie liest deshalb diesen vorher festgehaltenen Stand.
    var abschluss: ZirkelAbschluss? {
        zirkel.map { ZirkelAbschluss(zirkel: $0, begann: begann) }
    }

    /// `rundeBegann`: wann Runde 1 anfing, falls frueher als jetzt -- beim
    /// Zirkel aus einem Einzelsatz (Task 7) liegt dessen Satz vor dem Start.
    func starten(_ zirkel: Zirkel, jetzt: Date = Date(), rundeBegann: Date? = nil) {
        self.zirkel = zirkel
        pause = nil
        geschaffteRunde = nil
        rundenbeginn = rundeBegann ?? jetzt
        begann = rundenbeginn
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
    /// die Uhr nicht neu anfangen. Navigiert wird hier nie -- das macht der
    /// Pfad (TrainingRootView), und nur, solange die Pause oben liegt.
    ///
    /// Der letzte Slot hatte Runde 1 schon abgeschlossen (geschaffteRunde,
    /// neuer Rundenbeginn). Mit der neuen Uebung laeuft sie weiter: das
    /// Fenster beginnt wieder beim alten Rundenbeginn, sonst fehlten der
    /// Rundenpause alle Saetze vor dem Erweitern.
    @discardableResult
    func erweitern(um uebung: ZirkelUebung) -> Bool {
        guard zirkel?.erweitern(um: uebung) == true else { return false }
        if let geschaffteRunde { rundenbeginn = geschaffteRunde.start }
        geschaffteRunde = nil
        return true
    }

    /// Gesicherte Saetze stehen in der Einheit, nicht hier -- Beenden
    /// verliert deshalb nichts.
    func beenden() {
        zirkel = nil
        pause = nil
        geschaffteRunde = nil
        rundenbeginn = nil
        begann = nil
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

/// Der Stand eines Zirkels fuer seine Uebersicht, festgehalten vor dem
/// Beenden (siehe ZirkelAblauf.abschluss). Die Saetze selbst stehen nicht
/// darin: die liest die Uebersicht aus der Einheit.
struct ZirkelAbschluss: Equatable {
    let zirkel: Zirkel
    let begann: Date?
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

    /// "Zirkel mit weiterem Gerät" aus der Pause einer Einzeluebung: die
    /// neue Zirkel-Uebung ersetzt deren Geraete-Screen, statt sich
    /// davorzulegen -- "Zurueck" fuehrte sonst in eine Uebung, die jetzt
    /// Slot 1 des Zirkels ist und nichts mehr davon weiss.
    ///
    /// nil, wenn oben kein Geraete-Screen einer Einzeluebung liegt (schon
    /// im Zirkel, oder der Pfad hat sich waehrend der Wahl geaendert).
    static func ausEinzeluebung(_ pfad: [GeraetRoute], zu ziel: GeraetRoute) -> [GeraetRoute]? {
        guard case .geraet(_, _, _, _, let zirkel) = pfad.last, !zirkel else { return nil }
        return pfad.dropLast() + [ziel]
    }

    /// "+ Übung zum Zirkel" gilt nur in der Pause nach der letzten Uebung
    /// von Runde 1. Der Zirkel allein reicht nicht: ist die Pause abgelaufen
    /// und die erste Uebung von Runde 2 schon offen, zaehlt er bis zu deren
    /// Satz noch "Runde 1 komplett" -- die neue Uebung landete dann im
    /// falschen Slot.
    static func kannErweitern(_ pfad: [GeraetRoute], zirkel: Zirkel?) -> Bool {
        pfad.last == .zirkelPause && zirkel?.kannErweitern == true
    }

    /// Nach "Überspringen" in der Pause: gleich weiter zur naechsten Uebung
    /// (bzw. zur Uebersicht, wenn nichts mehr kommt) -- ausser der
    /// uebersprungene Slot schloss die Runde. Dann steht jetzt die
    /// Rundenpause an, und die gehoert gezeigt statt uebergangen.
    static func nachUeberspringenWeiter(_ zirkel: Zirkel) -> Bool {
        zirkel.istFertig || !zirkel.naechsterSchrittIstRundenwechsel
    }
}
