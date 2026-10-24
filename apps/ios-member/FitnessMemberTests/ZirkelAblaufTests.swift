import Foundation
import Testing
@testable import FitnessMember

/// Die Ablaufebene ueber dem Geraete-Screen: Zeit kommt ueber `jetzt`
/// herein, deshalb laeuft hier alles ohne Uhr und ohne UI.
@MainActor
struct ZirkelAblaufTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func uebung(_ i: Int) -> ZirkelUebung {
        ZirkelUebung(station: "geraet:g\(i)", exerciseId: "e\(i)", token: nil)
    }

    private func gestartet(n: Int = 3, runden: Int = 3) -> ZirkelAblauf {
        let ablauf = ZirkelAblauf()
        ablauf.starten(Zirkel(uebungen: (1...n).map(uebung), runden: runden,
                              uebungspause: 20, rundenpause: 90))
        return ablauf
    }

    @Test func einGesicherterSatzStartetDieUebungspause() {
        let ablauf = gestartet()
        ablauf.satzGesichert(jetzt: t0)
        #expect(ablauf.pause?.gesamtdauer == 20)
        #expect(ablauf.pause?.start == t0)
        #expect(ablauf.zirkel?.schritt == 1)
    }

    @Test func nachDerRundeStartetDieRundenpause() {
        let ablauf = gestartet()
        for _ in 0..<3 { ablauf.satzGesichert(jetzt: t0) }
        #expect(ablauf.pause?.gesamtdauer == 90)
        #expect(ablauf.zirkel?.runde == 2)
    }

    @Test func nachDemLetztenSatzGibtEsKeinePause() {
        let ablauf = gestartet(n: 2, runden: 2)
        for _ in 0..<4 { ablauf.satzGesichert(jetzt: t0) }
        #expect(ablauf.pause == nil)
        #expect(ablauf.zirkel?.istFertig == true)
    }

    @Test func verlaengernWirktNurAufDieLaufendePause() {
        let ablauf = gestartet()
        // Ohne Pause gibt es nichts zu verlaengern -- und es entsteht auch
        // keine aus dem Nichts.
        ablauf.pauseVerlaengern()
        #expect(ablauf.pause == nil)

        ablauf.satzGesichert(jetzt: t0)
        ablauf.pauseVerlaengern()
        #expect(ablauf.pause?.gesamtdauer == 20 + Resttimer.verlaengerung)
        #expect(ablauf.pause?.endetAm == t0.addingTimeInterval(20 + Resttimer.verlaengerung))
    }

    @Test func beendenRaeumtAuf() {
        let ablauf = gestartet()
        ablauf.satzGesichert(jetzt: t0)
        ablauf.beenden()
        #expect(ablauf.zirkel == nil)
        #expect(ablauf.pause == nil)
    }

    /// Fix-Runde 1 (Minor 3): mit dem Wechsel zur naechsten Uebung endet die
    /// Pause -- wer danach fragt, ob eine laeuft (Task 7), bekommt nil.
    @Test func pauseVerlassenRaeumtNurDiePause() {
        let ablauf = gestartet()
        ablauf.satzGesichert(jetzt: t0)
        ablauf.pauseVerlassen()
        #expect(ablauf.pause == nil)
        #expect(ablauf.zirkel?.schritt == 1)
    }

    @Test func ueberspringenRuecktWeiterWieEinSatz() {
        let ablauf = gestartet(n: 2)
        ablauf.ueberspringen(jetzt: t0)
        #expect(ablauf.zirkel?.schritt == 1)
        #expect(ablauf.pause?.gesamtdauer == 20)
    }

    @Test func erweiternNurNachRundeEins() {
        let ablauf = gestartet(n: 2)
        #expect(ablauf.erweitern(um: uebung(9)) == false)
        for _ in 0..<2 { ablauf.satzGesichert(jetzt: t0) }
        let pause = ablauf.pause
        #expect(ablauf.erweitern(um: uebung(9)))
        #expect(ablauf.zirkel?.naechste == uebung(9))
        // Die laufende Pause bleibt, wie sie war (Review Focus Task 7).
        #expect(ablauf.pause == pause)
    }

    // MARK: - Pfad zwischen den Uebungen

    private let alt = GeraetRoute.geraet(station: "geraet:g1", exerciseId: "e1", token: nil, zirkel: 0)
    private let neu = GeraetRoute.geraet(station: "geraet:g2", exerciseId: "e2", token: nil, zirkel: 1)

    @Test func ausDerPauseErsetztDieNaechsteUebungPauseUndGeraet() {
        let pfad: [GeraetRoute] = [.kategorie(.freihantel), alt, .zirkelPause]
        #expect(ZirkelPfad.ausPause(pfad, zu: neu) == [.kategorie(.freihantel), neu])
    }

    /// Review Focus: laeuft die Pause ab, waehrend "Weiter" schon gedrueckt
    /// ist, steht der Pfad nicht mehr auf der Pause -- der zweite Aufruf
    /// darf nichts tun.
    @Test func einZweiterWechselNavigiertNichtNochmal() {
        let pfad: [GeraetRoute] = [alt, .zirkelPause]
        let einmal = ZirkelPfad.ausPause(pfad, zu: neu)
        #expect(einmal == [neu])
        #expect(ZirkelPfad.ausPause(einmal ?? [], zu: neu) == nil)
    }

    /// Finding C-1 der Gesamtpruefung: Zirkel [A, B], Runde 2. A gesichert,
    /// in der Pause B uebersprungen -- die naechste Route ist wieder A ohne
    /// Startwerte. Waere sie gleich der Route unter der Pause, machte der
    /// NavigationStack aus [A, Pause] -> [A] ein Pop: der alte Screen mit
    /// seinem gesperrten Modell kaeme zurueck, "Satz sichern" bliebe tot.
    @Test func jederSlotBekommtEineEigeneRoute() {
        let ablauf = gestartet(n: 2)
        ablauf.satzGesichert(jetzt: t0)
        ablauf.satzGesichert(jetzt: t0)
        guard let runde2 = ablauf.zirkel, let a = runde2.naechste else {
            Issue.record("Zirkel fehlt"); return
        }
        let unterDerPause = ZirkelPfad.route(a, in: runde2)
        ablauf.satzGesichert(jetzt: t0)
        ablauf.ueberspringen(jetzt: t0)
        guard let runde3 = ablauf.zirkel, let wiederA = runde3.naechste else {
            Issue.record("Zirkel fehlt"); return
        }
        #expect(wiederA == a)
        let naechste = ZirkelPfad.route(wiederA, in: runde3)
        #expect(naechste != unterDerPause)
        let pfad = ZirkelPfad.ausPause([unterDerPause, .zirkelPause], zu: naechste)
        #expect(pfad == [naechste])
    }

    @Test func ohneGeraetUnterDerPauseFaelltNurDiePause() {
        #expect(ZirkelPfad.ausPause([.zirkelPause], zu: neu) == [neu])
    }

    /// Finding I-1: "Zirkel beenden" gibt es in der Pause UND auf dem
    /// Geraete-Screen einer Zirkel-Uebung (dort ohne Zurueck). Die Uebersicht
    /// ersetzt Pause samt Geraet bzw. den Geraete-Screen.
    @Test func zirkelBeendenFuehrtAusPauseUndGeraetZurUebersicht() {
        let einzel = GeraetRoute.geraet(station: "geraet:g1", exerciseId: "e1", token: nil)
        #expect(ZirkelPfad.zurUebersicht([.kategorie(.freihantel), alt, .zirkelPause])
                == [.kategorie(.freihantel), .zirkelUebersicht])
        #expect(ZirkelPfad.zurUebersicht([.kategorie(.freihantel), alt])
                == [.kategorie(.freihantel), .zirkelUebersicht])
        // Kein Zirkel-Screen oben: nichts (Einzeluebung, schon in der Uebersicht).
        #expect(ZirkelPfad.zurUebersicht([einzel]) == nil)
        #expect(ZirkelPfad.zurUebersicht([alt, .zirkelUebersicht]) == nil)
        #expect(ZirkelPfad.zurUebersicht([]) == nil)
    }

    // MARK: - Fix-Runde Task 5

    /// Die Rundenpause fasst nur Saetze der eben geschafften Runde
    /// zusammen: das Ablauf-Fenster beginnt mit dem Start bzw. dem letzten
    /// Rundenwechsel und endet mit dem Slot, der die Runde schliesst.
    @Test func dieGeschaffteRundeHatIhrZeitfenster() {
        let ablauf = ZirkelAblauf()
        ablauf.starten(Zirkel(uebungen: (1...2).map(uebung), runden: 3, uebungspause: 20, rundenpause: 90), jetzt: t0)
        #expect(ablauf.geschaffteRunde == nil)
        ablauf.satzGesichert(jetzt: t0.addingTimeInterval(60))
        #expect(ablauf.geschaffteRunde == nil)
        ablauf.ueberspringen(jetzt: t0.addingTimeInterval(120))
        #expect(ablauf.geschaffteRunde == DateInterval(start: t0, end: t0.addingTimeInterval(120)))
        ablauf.satzGesichert(jetzt: t0.addingTimeInterval(300))
        ablauf.satzGesichert(jetzt: t0.addingTimeInterval(400))
        #expect(ablauf.geschaffteRunde == DateInterval(start: t0.addingTimeInterval(120), end: t0.addingTimeInterval(400)))
    }

    /// Aus einem Einzelsatz (Task 7) lag der erste Satz vor dem Start: der
    /// Aufrufer gibt den Rundenbeginn mit.
    @Test func derRundenbeginnLaesstSichMitgeben() {
        let ablauf = ZirkelAblauf()
        let zirkel = Zirkel.ausEinzelsatz(uebung(1), zweite: uebung(2), runden: 3, uebungspause: 20, rundenpause: 90)
        ablauf.starten(zirkel, jetzt: t0.addingTimeInterval(100), rundeBegann: t0)
        ablauf.satzGesichert(jetzt: t0.addingTimeInterval(200))
        #expect(ablauf.geschaffteRunde == DateInterval(start: t0, end: t0.addingTimeInterval(200)))
    }

    /// Ueberspringen in der Uebungspause: mitten in der Runde gleich zur
    /// naechsten Uebung; schliesst es die Runde, bleibt man auf dem Screen,
    /// der jetzt die Rundenpause zeigt. Auf der Rundenpause selbst geht es
    /// weiter, ebenso nach dem letzten Slot (Uebersicht).
    @Test func ueberspringenFuehrtNurOhneRundenwechselGleichWeiter() {
        var zirkel = Zirkel(uebungen: (1...3).map(uebung), runden: 2, uebungspause: 20, rundenpause: 90)
        zirkel.weiter()
        zirkel.ueberspringen()               // Slot 2 von 3: mitten in der Runde
        #expect(ZirkelPfad.nachUeberspringenWeiter(zirkel))
        zirkel.ueberspringen()               // Slot 3 schliesst Runde 1
        #expect(!ZirkelPfad.nachUeberspringenWeiter(zirkel))
        zirkel.ueberspringen()               // auf der Rundenpause: erste Uebung von Runde 2
        #expect(ZirkelPfad.nachUeberspringenWeiter(zirkel))
        zirkel.weiter(); zirkel.weiter()
        zirkel.ueberspringen()               // letzter Slot: fertig
        #expect(zirkel.istFertig)
        #expect(ZirkelPfad.nachUeberspringenWeiter(zirkel))
    }
}
