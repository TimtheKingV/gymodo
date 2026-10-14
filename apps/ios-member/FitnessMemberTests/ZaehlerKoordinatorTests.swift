#if DEBUG
import Foundation
import Sensorik
import Testing
@testable import FitnessMember

@MainActor
struct ZaehlerKoordinatorTests {
    static let verbunden = SensorZustand.verbunden(name: "WT901BLE67", akkuProzent: 82)
    final class Uhr { var t: TimeInterval = 100 }
    final class Meldungen { var liste: [ZaehlerMeldung] = [] }

    private func aufbau(zustand: SensorZustand = verbunden,
                        einstellungen: UserDefaults = UserDefaults(suiteName: UUID().uuidString)!)
        -> (sut: ZaehlerKoordinator, quelle: AttrappenQuelle, uhr: Uhr, meldungen: Meldungen) {
        let quelle = AttrappenQuelle()
        quelle.zustand = zustand
        let uhr = Uhr()
        let sut = ZaehlerKoordinator(quelle: quelle, einstellungen: einstellungen, uhr: { uhr.t })
        return (sut, quelle, uhr, Meldungen())
    }

    private func beginnen(_ sut: ZaehlerKoordinator, _ m: Meldungen,
                          _ kontext: SatzZaehlerKontext = BefestigungsspeicherTests.kontext()) {
        sut.satzBeginnt(kontext) { m.liste.append($0) }
    }

    /// Stapel-Satz wie in Synthetik (Package): 3 s Ruhe, je Wiederholung
    /// 2 s Sinus mit 0,4 m/s Spitze entlang z, 2 s Ruhe. Ab Zeit `ab`.
    static func stapelSatz(wiederholungen: Int, ab: TimeInterval) -> [SensorMesswert] {
        let dt = 1.0 / 50
        var a: [Double] = Array(repeating: 0, count: 150)
        for k in 0..<(wiederholungen * 100) {
            a.append(0.4 * 2 * .pi / 2 * cos(2 * .pi * Double(k) * dt / 2))
        }
        a += Array(repeating: 0, count: 100)
        return a.enumerated().map { i, wert in
            SensorMesswert(t: ab + Double(i) * dt, beschleunigung: Vektor3(x: 0, y: 0, z: 1 + wert / 9.81),
                           drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0))
        }
    }

    @Test func bereitDannStandJeWiederholung() throws {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        #expect(m.liste == [.bereit])
        for w in Self.stapelSatz(wiederholungen: 5, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        #expect(m.liste == [.bereit, .stand(1), .stand(2), .stand(3), .stand(4), .stand(5)])
        let ergebnis = try #require(sut.ergebnis())
        #expect(ergebnis.gezaehlt == 5)
        #expect(ergebnis.repEvents.algo == "stapel/2")
        #expect(ergebnis.repEvents.befestigungsart == .stapel)
        // Zeiten relativ zum Satzbeginn: die erste Wiederholung beginnt nach 3 s Ruhe.
        #expect(abs(try #require(ergebnis.repEvents.wiederholungen.first).beginn - 3) <= 0.3)
        #expect(sut.meldung == nil)
    }

    @Test func messwerteVorDemSatzbeginnZaehlenNicht() {
        let (sut, _, uhr, m) = aufbau()
        let frueh = Self.stapelSatz(wiederholungen: 3, ab: uhr.t - 20)
        beginnen(sut, m)
        for w in frueh { sut.empfangen(.messwert(w)) }
        #expect(m.liste == [.bereit])
    }

    /// Spec 9: nach einer Luecke steht die Zahl, und nach dem Wiederverbinden
    /// wird nicht weitergezaehlt.
    @Test func lueckeMachtPruefenUndDanachKommtNichtsMehr() {
        let (sut, quelle, uhr, m) = aufbau()
        beginnen(sut, m)
        let satz = Self.stapelSatz(wiederholungen: 6, ab: uhr.t)
        for w in satz.prefix(400) { sut.empfangen(.messwert(w)) }
        let vorher = m.liste.last
        sut.empfangen(.zustand(.getrennt(wirdNeuVerbunden: true)))
        guard case .stand(let n)? = vorher else { Issue.record("kein Stand vor der Luecke"); return }
        #expect(m.liste.last == .pruefen(n, .luecke))
        quelle.zustand = Self.verbunden
        sut.empfangen(.zustand(Self.verbunden))
        for w in satz.dropFirst(400) { sut.empfangen(.messwert(w)) }
        #expect(m.liste.last == .pruefen(n, .luecke))
    }

    @Test func sekundenuebungZaehltNicht() {
        let (sut, _, _, m) = aufbau()
        beginnen(sut, m, SatzZaehlerKontext(station: Station(maschine: GeraetTestdaten.maschine),
                                            exerciseId: "e1", volumeKind: .seconds))
        #expect(m.liste == [.zaehltNicht(.keineWiederholungen)])
        #expect(sut.ergebnis() == nil)
    }

    @Test func cardioOhneVorschlagZaehltNicht() {
        let (sut, _, _, m) = aufbau()
        beginnen(sut, m, SatzZaehlerKontext(station: GeraetTestdaten.cardioTyp, exerciseId: "e9", volumeKind: .reps))
        #expect(m.liste == [.zaehltNicht(.keineBefestigung)])
    }

    /// Spec 9: der Sensor verbindet sich mitten in der Eingabe -- ab da zaehlt er.
    @Test func ohneSensorZaehltNichtUndStartetBeimVerbinden() {
        let (sut, quelle, _, m) = aufbau(zustand: .aus)
        beginnen(sut, m)
        #expect(m.liste == [.zaehltNicht(.keinSensor)])
        quelle.zustand = Self.verbunden
        sut.empfangen(.zustand(Self.verbunden))
        #expect(m.liste == [.zaehltNicht(.keinSensor), .bereit])
    }

    /// Review Focus 2: eine neue Art beginnt von vorn und ist gemerkt.
    @Test func befestigungWaehlenStartetNeuUndIstGemerkt() {
        let einstellungen = UserDefaults(suiteName: UUID().uuidString)!
        let (sut, _, uhr, m) = aufbau(einstellungen: einstellungen)
        beginnen(sut, m)
        for w in Self.stapelSatz(wiederholungen: 2, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        sut.befestigungWaehlen(.hebelarm)
        #expect(m.liste.last == .bereit)
        #expect(sut.befestigung == BefestigungsWahl(art: .hebelarm, quelle: .gewaehlt))
        #expect(sut.ergebnis() == nil)
        #expect(Befestigungsspeicher(einstellungen: einstellungen)
            .wahl(fuer: BefestigungsspeicherTests.kontext())?.art == .hebelarm)
    }

    @Test func satzVerworfenSchweigtDanach() {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        sut.satzVerworfen()
        for w in Self.stapelSatz(wiederholungen: 3, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        #expect(m.liste == [.bereit])
        #expect(sut.ergebnis() == nil)
        #expect(sut.meldung == nil)
    }

    @Test func ohneWiederholungIstDasErgebnisNil() {
        let (sut, _, _, m) = aufbau()
        beginnen(sut, m)
        #expect(sut.ergebnis() == nil)
        // Die Art bleibt fuer die Aufnahme lesbar.
        #expect(sut.befestigung?.art == .stapel)
    }
}
#endif
