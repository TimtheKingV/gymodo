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

    private let alt = GeraetRoute.geraet(station: "geraet:g1", exerciseId: "e1", token: nil, zirkel: true)
    private let neu = GeraetRoute.geraet(station: "geraet:g2", exerciseId: "e2", token: nil, zirkel: true)

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

    @Test func ohneGeraetUnterDerPauseFaelltNurDiePause() {
        #expect(ZirkelPfad.ausPause([.zirkelPause], zu: neu) == [neu])
    }
}
