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

    /// Kurzhantel-Satz: Aufheben, Wiederholungen der Beschleunigung im Takt
    /// 1,9 s (Hantel dreht sich nicht, wie beim Druecken), 3 s Ablegen.
    static func kurzhantelSatz(wiederholungen n: Int, ab: TimeInterval) -> [SensorMesswert] {
        let dt = 1.0 / 50
        let takt = 1.9, vorlauf = 2.0
        let gesamt = vorlauf + Double(n) * takt + 3
        return (0..<Int(gesamt * 50)).map { i in
            let t = Double(i) * dt
            var y = 1.0
            if t < vorlauf { y += 0.8 * sin(t * .pi / vorlauf) }
            else if t < vorlauf + Double(n) * takt { y += 0.3 * sin((t - vorlauf) * 2 * .pi / takt) }
            return SensorMesswert(t: ab + t, beschleunigung: Vektor3(x: 0, y: y, z: 0.05),
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
        #expect(ergebnis.repEvents.algo == "stapel/takt1")
        #expect(ergebnis.repEvents.befestigungsart == .stapel)
        // Zeiten relativ zum Satzbeginn: die erste Wiederholung beginnt nach 3 s Ruhe;
        // der Takt legt Abschnitte im Viertel-Takt-Raster, daher +-1 s statt +-0,3 s.
        let erste = try #require(ergebnis.repEvents.wiederholungen.first)
        #expect(abs(erste.beginn - 3) <= 1)
        #expect(sut.meldung == nil)
    }

    /// Kurzhantel: Satz mit Aufheben, 8 Wiederholungen der Beschleunigung
    /// (Hantel dreht sich nicht, wie beim Druecken) und Ablegen. Die
    /// Live-Zahl kennt das nicht; am Satzende zaehlt die Takt-Auswertung.
    @Test func kurzhantelZaehltAmSatzendeNachDemTakt() throws {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        sut.befestigungWaehlen(.kurzhantel)
        let n = 8
        for w in Self.kurzhantelSatz(wiederholungen: n, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        let ergebnis = try #require(sut.ergebnis())
        #expect(abs(ergebnis.gezaehlt - n) <= 1)
        #expect(ergebnis.repEvents.algo == Satztakt.algo)
        #expect(ergebnis.repEvents.wiederholungen.count == ergebnis.gezaehlt)
    }

    /// Aufnahme vom 18.10. (Repo-Wurzel ueber den Pfad dieser Datei) als Messwert-Strom ab `ab`.
    private static func aufnahme(_ name: String, ab: TimeInterval) throws -> [SensorMesswert] {
        let wurzel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let (_, eintraege) = try SensorAufnahmeLeser.lesen(
            ordner: wurzel.appendingPathComponent("data/sensoraufnahmen/\(name)"))
        return eintraege.compactMap { eintrag in
            guard case .messwert(let m) = eintrag else { return nil }
            return SensorMesswert(t: ab + m.t, beschleunigung: m.beschleunigung, drehrate: m.drehrate, winkel: m.winkel)
        }
    }

    /// Wadenheben am Stapel, 20 Wiederholungen: die Live-Zahl lag bei 2.
    @Test func stapelZaehltAmSatzendeNachDemTakt() throws {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        sut.befestigungWaehlen(.stapel)
        for w in try Self.aufnahme("2026-10-18-1642-01", ab: uhr.t) { sut.empfangen(.messwert(w)) }
        let ergebnis = try #require(sut.ergebnis())
        #expect(abs(ergebnis.gezaehlt - 20) <= 1)
        #expect(ergebnis.repEvents.algo == "stapel/takt1")
    }

    /// Hebelarm hat kein Takt-Profil: die Live-Zahl bleibt.
    @Test func hebelarmBleibtBeiDerLiveZahl() {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        sut.befestigungWaehlen(.hebelarm)
        for w in Self.kurzhantelSatz(wiederholungen: 8, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        #expect(sut.satzMesswerteAnzahl == 0)
        #expect(sut.ergebnis()?.repEvents.algo != "hebelarm/takt1")
    }

    /// Ein Satz ueber 150 s waechst nicht unbegrenzt im Speicher; er zaehlt
    /// danach wieder mit der Live-Zahl (die Takt-Auswertung wird quadratisch teuer).
    @Test func langerSatzBegrenztDenPuffer() {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        sut.befestigungWaehlen(.stapel)
        for w in Self.kurzhantelSatz(wiederholungen: 100, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        #expect(sut.satzMesswerteAnzahl > 7000 && sut.satzMesswerteAnzahl <= 7500 + 250)
        #expect(sut.ergebnis()?.repEvents.algo != "stapel/takt1")
    }

    /// Hat die Live-Auswertung den ganzen Satz schon gesehen, rechnet das
    /// Satzende nicht noch einmal (Debug-Build: Sekunden auf dem Main Actor).
    @Test func satzendeNutztDieFertigeLiveAuswertung() async throws {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        sut.befestigungWaehlen(.kurzhantel)
        for w in Self.kurzhantelSatz(wiederholungen: 8, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        func letzterStand() -> Int? { m.liste.compactMap { if case .stand(let n) = $0 { n } else { nil } }.last }
        for _ in 0..<300 where letzterStand() != 8 { try await Task.sleep(for: .milliseconds(50)) }
        let ergebnis = try #require(sut.ergebnis())
        #expect(abs(ergebnis.gezaehlt - 8) <= 1)
        #expect(sut.syncAuswertungen == 0)
    }

    /// Testnotiz 16.10., #4: das Rad folgt an der Kurzhantel der
    /// Takt-Auswertung, nicht der Live-Zahl -- die letzte Meldung ist die
    /// Zahl, die gespeichert wird.
    @Test func kurzhantelMeldetLiveDieTaktzahl() async throws {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        sut.befestigungWaehlen(.kurzhantel)
        for w in Self.kurzhantelSatz(wiederholungen: 8, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        // Der Takt rechnet abseits des Main Actors; warten, bis er die
        // Endzahl meldet (Debug-Build: rund eine Sekunde je Auswertung).
        func letzterStand() -> Int? { m.liste.compactMap { if case .stand(let n) = $0 { n } else { nil } }.last }
        for _ in 0..<300 where letzterStand() != 8 { try await Task.sleep(for: .milliseconds(50)) }
        let gemeldet = letzterStand()
        let ergebnis = try #require(sut.ergebnis())
        #expect(gemeldet == ergebnis.gezaehlt)
    }

    /// Ein Ergebnis, das nach dem Satzende eintrifft, meldet nichts mehr.
    @Test func einSpaeterTaktNachDemSatzSchweigt() async throws {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        sut.befestigungWaehlen(.kurzhantel)
        for w in Self.kurzhantelSatz(wiederholungen: 8, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        // Die erste Auswertung (nach 1 s Messzeit, zu kurz fuer den Takt)
        // endet sofort und stoesst die mit dem ganzen Satz an -- die laeuft
        // rund eine Sekunde und kommt erst nach dem Verwerfen zurueck.
        try await Task.sleep(for: .milliseconds(100))
        sut.satzVerworfen()
        try await Task.sleep(for: .seconds(3))
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
        quelle.zustand = .getrennt(wirdNeuVerbunden: true)
        sut.empfangen(.zustand(.getrennt(wirdNeuVerbunden: true)))
        guard case .stand(let n)? = vorher else { Issue.record("kein Stand vor der Luecke"); return }
        #expect(m.liste.last == .pruefen(n, .luecke))
        quelle.zustand = Self.verbunden
        sut.empfangen(.zustand(Self.verbunden))
        for w in satz.dropFirst(400) { sut.empfangen(.messwert(w)) }
        #expect(m.liste.last == .pruefen(n, .luecke))
    }

    /// Review I1: reisst die Verbindung vor der ersten Wiederholung ab, gibt
    /// es nichts zu schuetzen -- nach dem Wiederverbinden zaehlt der Satz.
    @Test func trennungVorDerErstenWiederholungZaehltNachDemVerbinden() {
        let (sut, quelle, uhr, m) = aufbau()
        beginnen(sut, m)
        quelle.zustand = .getrennt(wirdNeuVerbunden: true)
        sut.empfangen(.zustand(.getrennt(wirdNeuVerbunden: true)))
        #expect(m.liste == [.bereit, .zaehltNicht(.keinSensor)])
        uhr.t = 110
        quelle.zustand = Self.verbunden
        sut.empfangen(.zustand(Self.verbunden))
        for w in Self.stapelSatz(wiederholungen: 3, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        #expect(m.liste.last == .stand(3))
    }

    /// Review M4: ein Trennungs-Ereignis, das erst ankommt, wenn die Quelle
    /// schon wieder verbunden ist, darf den neuen Satz nicht anhalten.
    @Test func eineVerspaeteteTrennungHaeltDenSatzNichtAn() {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        sut.empfangen(.zustand(.getrennt(wirdNeuVerbunden: true)))
        for w in Self.stapelSatz(wiederholungen: 2, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        #expect(m.liste == [.bereit, .stand(1), .stand(2)])
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
