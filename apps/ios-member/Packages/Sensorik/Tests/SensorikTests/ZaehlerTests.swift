import Foundation
import Testing
@testable import Sensorik

struct ZaehlerTests {
    typealias A = Synthetik.Abschnitt

    @Test(arguments: [Befestigungsart.kurzhantel, .hebelarm, .kabelgriff])
    func drehrateZaehltJedePeriode(art: Befestigungsart) {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)])
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: art)) == 10)
    }

    @Test(arguments: [Befestigungsart.stapel, .koerper])
    func geschwindigkeitZaehltJedePeriode(art: Befestigungsart) {
        let werte = Synthetik.satz(signal: .geschwindigkeitVertikal, abschnitte: [A(perioden: 10)])
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: art)) == 10)
    }

    @Test func nurRuheZaehltNichts() {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [], ruheVorher: 20)
        let ereignisse = Synthetik.zaehlen(werte, art: .hebelarm)
        #expect(ereignisse == [.zuende])
    }

    /// Spec A 4.7: bei 50 Hz zwei, bei 100 Hz vier Messwerte je Zeitstempel.
    @Test(arguments: [1, 2, 4])
    func buendelungAendertDieZahlNicht(buendel: Int) {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 8)], buendel: buendel)
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .hebelarm)) == 8)
    }

    @Test func zwanzigUndHundertHzZaehlenGleich() {
        for rate in [20.0, 100.0] {
            let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 8)], rate: rate, buendel: 1)
            #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .hebelarm, rate: rate)) == 8)
        }
    }

    @Test func leichtesRauschenZaehltNichtMit() {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)], rauschenGradProS: 8)
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .hebelarm)) == 10)
    }

    @Test func eineLueckeImSatzMachtUnsicherUndDanachKommtNichtsMehr() {
        // Ruhe 3 s, dann Perioden zu 2 s: die Luecke bei 10 s liegt in der vierten.
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)], luecke: (ab: 10, dauer: 1))
        let ereignisse = Synthetik.zaehlen(werte, art: .hebelarm)
        let index = ereignisse.firstIndex(of: .unsicher(.luecke))
        #expect(index != nil)
        if let index {
            #expect(Synthetik.anzahl(Array(ereignisse[index...])) == 0)
        }
        #expect(Synthetik.anzahl(ereignisse) < 10)
        #expect(ereignisse.last == .zuende)
    }

    @Test func eineExpliziteLueckeWirktWieEineImplizite() {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 6)])
        var zaehler = Zaehler(profil: .fuer(.hebelarm))
        var ereignisse: [ZaehlerEreignis] = []
        for m in werte.prefix(werte.count / 2) { ereignisse += zaehler.verarbeite(m) }
        ereignisse += zaehler.luecke(von: 7, bis: 7.2)
        for m in werte.suffix(werte.count / 2) { ereignisse += zaehler.verarbeite(m) }
        #expect(ereignisse.contains(.unsicher(.luecke)))
        #expect(Synthetik.anzahl(Array(ereignisse.drop(while: { $0 != .unsicher(.luecke) }))) == 0)
    }

    /// 0,38 der Grundamplitude liegt ueber der Schwelle nach der ersten
    /// Wiederholung (0,35) und unter dem Schwach-Anteil (0,4): sie wird
    /// erkannt, aber als zu schwach bewertet.
    @Test func eineSchwacheWiederholungAmEndeMachtUnsicher() {
        let werte = Synthetik.satz(signal: .drehrate,
                                   abschnitte: [A(perioden: 8), A(perioden: 1, amplitude: 0.38)])
        let ereignisse = Synthetik.zaehlen(werte, art: .hebelarm)
        #expect(Synthetik.anzahl(ereignisse) == 8)
        #expect(ereignisse.contains(.unsicher(.signalSchwach)))
    }

    @Test func eineVielZuLangsameWiederholungMachtUnsicher() {
        let werte = Synthetik.satz(signal: .drehrate,
                                   abschnitte: [A(perioden: 6), A(perioden: 1, periode: 7)])
        let ereignisse = Synthetik.zaehlen(werte, art: .hebelarm)
        #expect(Synthetik.anzahl(ereignisse) == 6)
        #expect(ereignisse.contains(.unsicher(.taktUnregelmaessig)))
    }

    @Test func gleicherEingangGibtGleicheEreignisse() {
        let werte = Synthetik.satz(signal: .geschwindigkeitVertikal, abschnitte: [A(perioden: 7)])
        #expect(Synthetik.zaehlen(werte, art: .stapel) == Synthetik.zaehlen(werte, art: .stapel))
    }

    @Test func ereignisseSindInSichStimmig() {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)])
        let wiederholungen = Synthetik.zaehlen(werte, art: .hebelarm).compactMap {
            if case .wiederholung(let w) = $0 { w } else { nil }
        }
        #expect(wiederholungen.map(\.nummer) == Array(1...10))
        for w in wiederholungen {
            #expect(w.beginn < w.umkehr && w.umkehr < w.ende)
            #expect((0...1).contains(w.sicherheit))
        }
        #expect(wiederholungen.first?.pauseDavor == nil)
        #expect(wiederholungen.dropFirst().allSatisfy { $0.pauseDavor != nil })
        // Ruhevorlauf 3 s: die erste Wiederholung beginnt nicht davor.
        #expect((wiederholungen.first?.beginn ?? 0) >= 2.8)
    }

    @Test func dasProfilKenntSeineAlgoKennung() {
        #expect(ZaehlerProfil.fuer(.langhantel).algo == "langhantel/2")
        #expect(ZaehlerProfil.fuer(.kurzhantel).algo == "kurzhantel/2")
        #expect(ZaehlerProfil.fuer(.hebelarm).algo == "hebelarm/1")
        #expect(ZaehlerProfil.fuer(.kabelgriff).algo == "kabelgriff/1")
        #expect(ZaehlerProfil.fuer(.stapel).algo == "stapel/2")
        #expect(ZaehlerProfil.fuer(.stapel).signal == .geschwindigkeitBetrag)
        #expect(ZaehlerProfil.fuer(.langhantel).signal == .geschwindigkeitBetrag)
        #expect(ZaehlerProfil.fuer(.koerper).signal == .geschwindigkeitVertikal)
        #expect(ZaehlerProfil.fuer(.kurzhantel).signal == .drehrate)
    }

    // MARK: - Aufnehmen und Ablegen (15.10.)

    /// Das Aufnehmen der Hantel um eine andere Achse legt die Achse nicht
    /// fest: es endet in einer anderen Lage, als es begann, und ist darum
    /// keine Wiederholung.
    @Test func kurzhantelAufnehmenUmEineAndereAchseLegtDieAchseNichtFest() {
        let werte = Synthetik.folge([.ruhe(3), .lagewechsel(achse: 2), .ruhe(0.5), .curls(8), .ruhe(2)])
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .kurzhantel)) == 8)
    }

    /// Um dieselbe Achse wie die Curls: das Aufnehmen zaehlt nicht als
    /// erste Wiederholung und legt die Richtung nicht fest.
    @Test func kurzhantelAufnehmenUmDieCurlAchseZaehltNicht() {
        let werte = Synthetik.folge([.ruhe(3), .lagewechsel(achse: 1), .ruhe(0.5), .curls(8), .ruhe(2)])
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .kurzhantel)) == 8)
    }

    @Test func kurzhantelAblegenNachDemSatzZaehltNicht() {
        let werte = Synthetik.folge([.ruhe(3), .curls(8), .lagewechsel(achse: 1), .ruhe(2)])
        let ereignisse = Synthetik.zaehlen(werte, art: .kurzhantel)
        #expect(Synthetik.anzahl(ereignisse) == 8)
        #expect(!ereignisse.contains { if case .unsicher = $0 { true } else { false } })
    }

    /// Ein Schwung hin und zurueck in die Ausgangslage mit einem Stoss ueber
    /// 3 g (Hantel aus der Ablage gerissen) ist vor der ersten Wiederholung
    /// keine Wiederholung und legt keine Achse fest.
    @Test func kurzhantelEinStossVorDerErstenWiederholungLegtNichtsFest() {
        let schwung = Synthetik.Stueck(
            dauer: 1.2,
            drehrate: { u in Vektor3(x: 300 * sin(2 * .pi * u / 1.2), y: 0, z: 0) },
            beschleunigung: { u in Vektor3(x: 0, y: 0, z: u >= 0.2 && u < 0.3 ? 3.5 : 1) })
        let werte = Synthetik.folge([.ruhe(3), schwung, .ruhe(0.5), .curls(8), .ruhe(2)])
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .kurzhantel)) == 8)
    }

    /// Spec B: eine Wiederholung dauert ueber eine Sekunde. Ein kurzes
    /// Hin und Her beim Greifen zaehlt nicht.
    @Test func kurzhantelEinKurzesHinUndHerZaehltNicht() {
        let werte = Synthetik.folge([.ruhe(3), .curls(1, periode: 0.7), .ruhe(1), .curls(8), .ruhe(2)])
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .kurzhantel)) == 8)
    }

    /// Langhantel ueber den Betrag wie der Stapel; das Einhaengen der
    /// Stange am Ende dreht sie um 120 Grad und zaehlt nicht mit.
    @Test func langhantelEinhaengenNachDemSatzZaehltNicht() {
        let werte = Synthetik.satz(signal: .geschwindigkeitBetrag,
                                   abschnitte: [A(perioden: 10), A(perioden: 1)]).map { m in
            guard m.t >= 23, m.t < 25 else { return m }
            return SensorMesswert(t: m.t, beschleunigung: m.beschleunigung,
                                  drehrate: Vektor3(x: 60, y: 0, z: 0), winkel: m.winkel)
        }
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .langhantel)) == 10)
    }

    /// Spec B 5.3 "Achse der ersten Bewegung": ein kurzer Stoss um eine
    /// andere Achse im Ruhevorlauf darf die Achse nicht festlegen. 9 Grad/s
    /// Bias auf der Bewegungsachse ist der Rand des unterstuetzten Bereichs
    /// (Gleichanteil deutlich unter ruheDrehrate, siehe ZaehlerProfil).
    @Test(arguments: [0.0, 9.0])
    func einKurzerStossImVorlaufAendertDieZahlNicht(bias: Double) {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)]).map { m in
            let x = m.t >= 1 && m.t < 1.1 ? 100 : m.drehrate.x
            return SensorMesswert(t: m.t, beschleunigung: m.beschleunigung,
                                  drehrate: Vektor3(x: x, y: m.drehrate.y + bias, z: m.drehrate.z), winkel: m.winkel)
        }
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .hebelarm)) == 10)
    }

    private static func ersteWiederholung(_ ereignisse: [ZaehlerEreignis]) -> Wiederholung? {
        for e in ereignisse { if case .wiederholung(let w) = e { return w } }
        return nil
    }

    /// Spec B 5.3 "der Ruhevorlauf zaehlt nie": ein Gleichanteil der
    /// Drehrate (Sensor-Bias) darf den Beginn nicht in den Vorlauf ziehen.
    /// 9 Grad/s ist der Rand des unterstuetzten Bereichs (siehe ZaehlerProfil).
    @Test(arguments: [5.0, 9.0])
    func einDrehratenBiasZiehtDenBeginnNichtInDenVorlauf(bias: Double) throws {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)]).map { m in
            SensorMesswert(t: m.t, beschleunigung: m.beschleunigung,
                           drehrate: Vektor3(x: m.drehrate.x, y: m.drehrate.y + bias, z: m.drehrate.z), winkel: m.winkel)
        }
        let ereignisse = Synthetik.zaehlen(werte, art: .hebelarm)
        #expect(Synthetik.anzahl(ereignisse) == 10)
        let erste = try #require(Self.ersteWiederholung(ereignisse))
        #expect(abs(erste.beginn - 3) <= 0.3)
    }

    /// Wie oben fuer das Geschwindigkeitssignal: ein kleiner konstanter
    /// Versatz der Beschleunigung, der erst bei 1 s einsetzt (Sensor nach dem
    /// Greifen leicht verkippt). Die Schwerkraftschaetzung holt ihn bis zum
    /// Satzbeginn nur teilweise ein; der Rest wird zu einem Gleichanteil der
    /// Geschwindigkeit. Ab Aufnahmebeginn waere er schon in der Schaetzung.
    /// Nur koerper: der Stapel nimmt den Betrag, den eine Verkippung nicht
    /// aendert (siehe eineVerkippungImSatzAendertDieStapelZahlNicht).
    @Test func einBeschleunigungsVersatzZiehtDenBeginnNichtInDenVorlauf() throws {
        let werte = Synthetik.satz(signal: .geschwindigkeitVertikal, abschnitte: [A(perioden: 10)]).map { m in
            guard m.t >= 1 else { return m }
            return SensorMesswert(t: m.t, beschleunigung: Vektor3(x: m.beschleunigung.x, y: m.beschleunigung.y,
                                                                  z: m.beschleunigung.z + 0.015),
                                  drehrate: m.drehrate, winkel: m.winkel)
        }
        let ereignisse = Synthetik.zaehlen(werte, art: .koerper)
        #expect(Synthetik.anzahl(ereignisse) == 10)
        let erste = try #require(Self.ersteWiederholung(ereignisse))
        #expect(abs(erste.beginn - 3) <= 0.3)
    }

    /// 0,18 der Grundamplitude sind 36 Grad/s Spitze: ueber der
    /// Startschwelle (30), aber die meiste Zeit unter der Bewegungsschwelle
    /// der Achsensuche (30). Der Satz muss trotzdem gezaehlt werden.
    @Test(arguments: [Befestigungsart.hebelarm, .kabelgriff])
    func einKleinerAusschlagWirdGezaehlt(art: Befestigungsart) {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10, amplitude: 0.18)])
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: art)) == 10)
    }

    /// Aufnahme beginnt mitten in der Bewegung, auf der Spitze der ersten
    /// Halbwelle (kein Ruhevorlauf): die angeschnittene erste und neun
    /// volle Wiederholungen.
    @Test func ohneRuhevorlaufAufDerSpitzeZaehltAlle() {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)], ruheVorher: 0)
            .filter { $0.t >= 0.5 }
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .hebelarm)) == 10)
    }

    /// Stapel wie am 14.10. (Trizeps, Brustpresse): langsamer Hub, schnelles
    /// Absenken. Der Hub bleibt unter 0,05 g und sieht damit fuer die
    /// Ruhepruefung wie Ruhe aus; er darf weder als Ruhe-Grundlinie enden
    /// noch die Wiederholungen gegeneinander verschieben.
    @Test(arguments: [10, 15])
    func stapelZaehltBeiLangsamemHub(wiederholungen: Int) {
        let werte = Self.stapelSatz(wiederholungen: wiederholungen) { _ in Vektor3(x: 0, y: 0, z: 1) }
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .stapel)) == wiederholungen)
    }

    /// Die Scheibe kippt nach der ersten Wiederholung um 10 Grad (Sensor
    /// rutscht, Stapel schlaegt an). In Bewegung wird die Schwerkraft nicht
    /// nachgefuehrt; eine Projektion auf die alte Richtung saehe einen
    /// Versatz von 1,5 Prozent g und liefe davon. Der Betrag sieht ihn nicht.
    @Test func eineVerkippungImSatzAendertDieStapelZahlNicht() {
        let kipp = 10 * Double.pi / 180
        let werte = Self.stapelSatz(wiederholungen: 10) { t in
            t < 5 ? Vektor3(x: 0, y: 0, z: 1) : Vektor3(x: sin(kipp), y: 0, z: cos(kipp))
        }
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .stapel)) == 10)
    }

    /// Je Wiederholung 1,4 s Hub mit 0,2 m/s Spitze und 0,6 s Absenken mit
    /// 0,47 m/s Spitze (gleicher Weg), 3 s Ruhe davor, 2 s danach. `richtung`
    /// gibt die Lage der Schwerkraft im Sensor je Zeitpunkt.
    private static func stapelSatz(wiederholungen: Int,
                                   richtung: (Double) -> Vektor3) -> [SensorMesswert] {
        let dt = 1.0 / 50
        let hub = 1.4, ab = 0.6
        let vHub = 0.2, vAb = vHub * hub / ab
        var a: [Double] = Array(repeating: 0, count: 150)
        for _ in 0..<wiederholungen {
            for k in 0..<Int(hub / dt) { a.append(vHub * .pi / hub * cos(.pi * Double(k) * dt / hub)) }
            for k in 0..<Int(ab / dt) { a.append(-vAb * .pi / ab * cos(.pi * Double(k) * dt / ab)) }
        }
        a += Array(repeating: 0, count: 100)
        return a.enumerated().map { i, wert in
            let t = Double(i / 2 * 2) * dt
            let g = richtung(t)
            let betrag = 1 + wert / 9.81
            return SensorMesswert(t: t, beschleunigung: Vektor3(x: g.x * betrag, y: g.y * betrag, z: g.z * betrag),
                                  drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0))
        }
    }
}
