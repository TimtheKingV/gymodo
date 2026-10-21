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

    func starten(_ zirkel: Zirkel) {
        self.zirkel = zirkel
        pause = nil
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
    }

    private func weiterruecken(jetzt: Date, _ schritt: (inout Zirkel) -> Void) {
        guard var zirkel else { return }
        schritt(&zirkel)
        self.zirkel = zirkel
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
}
